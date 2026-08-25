/*
 * beminder_ble.c
 * FoloToy 作为 BLE Peripheral，广播 Beminder Service。
 *
 * 特征值（与 iOS BeminderConstants.swift 一致）：
 *   SERVICE : B3E1F000-0000-1000-8000-00805F9B34FB
 *   STATE   : B3E1F001-0000-1000-8000-00805F9B34FB  (Read + Notify，上报状态/ACK)
 *   COMMAND : B3E1F002-0000-1000-8000-00805F9B34FB  (Write，iPhone 下发命令)
 *
 * 实现基于 ESP-IDF 的 NimBLE 主机（ble_gatts）。
 * FoloToy 的 demo 注册机制见 beminder_demo / 宿主固件接入点。
 */

#include <stdint.h>
#include <stdbool.h>
#include <string.h>

#include "esp_log.h"
#include "nvs_flash.h"

#include "nimble/nimble_port.h"
#include "nimble/nimble_port_freertos.h"
#include "host/ble_hs.h"
#include "host/util/util.h"
#include "services/gap/ble_svc_gap.h"
#include "services/gatt/ble_svc_gatt.h"

#include "beminder_config.h"
#include "beminder_ble.h"

static const char *TAG = "beminder_ble";

/* 当前 STATE（FoloToy 侧，只由 iPhone 命令驱动，不自己计时）。
 * 会被 NimBLE host task（GATT 写回调）与按键任务并发读写，
 * 用临界区保护读改写，避免跨任务数据竞争（L8）。 */
static uint8_t s_state = BEMINDER_STATE_IDLE;
static portMUX_TYPE s_state_lock = portMUX_INITIALIZER_UNLOCKED;

static void beminder_set_state(uint8_t new_state)
{
    portENTER_CRITICAL(&s_state_lock);
    s_state = new_state;
    portEXIT_CRITICAL(&s_state_lock);
}

static uint8_t beminder_get_state(void)
{
    uint8_t v;
    portENTER_CRITICAL(&s_state_lock);
    v = s_state;
    portEXIT_CRITICAL(&s_state_lock);
    return v;
}

/* UI 状态回调 */
static beminder_state_cb_t s_state_cb = NULL;

/* 已订阅 Notify 的连接，用于把状态变化推送给 iPhone */
static uint16_t s_notify_conn = 0;

/* STATE 特征值属性句柄（注册后填充，用于 Notify） */
static uint16_t s_state_val_handle = 0;

/* 广播地址类型，sync 后用 infer_auto 推断 */
static uint8_t s_adv_addr_type = BLE_OWN_ADDR_PUBLIC;

/* ---------- UUID ---------- */
static const ble_uuid128_t s_service_uuid = BLE_UUID128_INIT(BEMINDER_SERVICE_UUID);
static const ble_uuid128_t s_state_uuid   = BLE_UUID128_INIT(BEMINDER_STATE_UUID);
static const ble_uuid128_t s_command_uuid = BLE_UUID128_INIT(BEMINDER_COMMAND_UUID);

/* ---------- 前向声明 ---------- */
static int beminder_access(uint16_t conn_handle, uint16_t attr_handle,
                           struct ble_gatt_access_ctxt *ctxt, void *arg);
static int beminder_gap_event(struct ble_gap_event *event, void *arg);
static void beminder_start_advertising(void);
static void beminder_notify_state(uint16_t conn_handle);

/* ---------- GATT 服务定义 ---------- */

static const struct ble_gatt_svc_def beminder_gatt_svcs[] = {
    {
        .type = BLE_GATT_SVC_TYPE_PRIMARY,
        .uuid = &s_service_uuid.u,
        .characteristics = (struct ble_gatt_chr_def[]){
            {
                .uuid = &s_state_uuid.u,
                .access_cb = beminder_access,
                .flags = BLE_GATT_CHR_F_READ | BLE_GATT_CHR_F_NOTIFY,
                .val_handle = &s_state_val_handle,
            },
            {
                .uuid = &s_command_uuid.u,
                .access_cb = beminder_access,
                .flags = BLE_GATT_CHR_F_WRITE | BLE_GATT_CHR_F_WRITE_NO_RSP,
            },
            { 0 }, /* 结束 */
        },
    },
    { 0 }, /* 结束 */
};

/* ---------- 命令处理 ---------- */

static void beminder_apply_command(uint8_t cmd)
{
    uint8_t new_state;
    switch (cmd) {
    case BEMINDER_CMD_START:
    case BEMINDER_CMD_WARNING:
        new_state = cmd;
        break;
    case BEMINDER_CMD_RESET:
        new_state = BEMINDER_STATE_IDLE;
        break;
    default:
        /* M10：未知命令字节必须忽略并记日志，绝不能当作 RESET，
         * 否则写错一字节就会在用户不知情时终止守护与告警。 */
        ESP_LOGW(TAG, "unknown command 0x%02x ignored", cmd);
        return;
    }

    bool was_changed = (beminder_get_state() != new_state);
    beminder_set_state(new_state);

    if (was_changed && s_state_cb) {
        s_state_cb(new_state);
    }

    /* 把最新状态推给已订阅的 iPhone（无论是否变化都同步一次） */
    if (s_notify_conn != 0) {
        beminder_notify_state(s_notify_conn);
    }
    ESP_LOGI(TAG, "state -> %u", new_state);
}

/* ---------- 特征访问 ---------- */

static int beminder_access(uint16_t conn_handle, uint16_t attr_handle,
                           struct ble_gatt_access_ctxt *ctxt, void *arg)
{
    (void)conn_handle;
    (void)arg;

    if (ctxt->op == BLE_GATT_ACCESS_OP_READ_CHR) {
        if (attr_handle == s_state_val_handle) {
            /* 读 STATE：返回当前状态 */
            uint8_t cur = beminder_get_state();
            int rc = os_mbuf_append(ctxt->om, &cur, sizeof(cur));
            return rc == 0 ? 0 : BLE_ATT_ERR_INSUFFICIENT_RES;
        }
        return BLE_ATT_ERR_UNLIKELY;
    }

    if (ctxt->op == BLE_GATT_ACCESS_OP_WRITE_CHR) {
        uint8_t cmd;
        if (os_mbuf_copydata(ctxt->om, 0, 1, &cmd) < 0) {
            return BLE_ATT_ERR_INVALID_ATTR_VALUE_LEN;
        }
        beminder_apply_command(cmd);
        return 0;
    }

    return BLE_ATT_ERR_UNLIKELY;
}

static void beminder_notify_state(uint16_t conn_handle)
{
    uint8_t cur = beminder_get_state();
    struct os_mbuf *om = ble_hs_mbuf_from_flat(&cur, sizeof(cur));
    if (om == NULL) {
        return;
    }
    int rc = ble_gatts_notify_custom(conn_handle, s_state_val_handle, om);
    /* H2：ble_gatts_notify_custom 失败时无条件接管并释放 mbuf，
     * 应用层不得再 free_chain，否则构成双重释放导致堆损坏。 */
    (void)rc;
}

/* ---------- 广播 ---------- */

static void beminder_start_advertising(void)
{
    struct ble_gap_adv_params adv_params = { 0 };
    struct ble_hs_adv_fields fields = { 0 };

    fields.flags = BLE_HS_ADV_F_DISC_GEN | BLE_HS_ADV_F_BREDR_UNSUP;
    fields.name = (uint8_t *)BEMINDER_LOCAL_NAME;
    fields.name_len = strlen(BEMINDER_LOCAL_NAME);
    fields.name_is_complete = 1;
    fields.uuids128 = (ble_uuid128_t[]){ s_service_uuid };
    fields.num_uuids128 = 1;
    fields.uuids128_is_complete = 1;

    int rc = ble_gap_adv_set_fields(&fields);
    if (rc != 0) {
        ESP_LOGE(TAG, "adv set fields failed: %d", rc);
        return;
    }

    adv_params.conn_mode = BLE_GAP_CONN_MODE_UND;
    adv_params.disc_mode = BLE_GAP_DISC_MODE_GEN;

    rc = ble_gap_adv_start(s_adv_addr_type, NULL, BLE_HS_FOREVER,
                           &adv_params, beminder_gap_event, NULL);
    if (rc == 0) {
        ESP_LOGI(TAG, "advertising started");
    } else {
        ESP_LOGE(TAG, "adv start failed: %d", rc);
    }
}

static int beminder_gap_event(struct ble_gap_event *event, void *arg)
{
    (void)arg;
    switch (event->type) {
    case BLE_GAP_EVENT_ADV_COMPLETE:
        beminder_start_advertising();
        break;
    case BLE_GAP_EVENT_CONNECT:
        s_notify_conn = 0;
        if (event->connect.status != 0) {
            /* 建链失败，重开广播 */
            beminder_start_advertising();
        }
        break;
    case BLE_GAP_EVENT_DISCONNECT:
        s_notify_conn = 0;
        beminder_start_advertising();
        break;
    case BLE_GAP_EVENT_SUBSCRIBE:
        s_notify_conn = (event->subscribe.cur_notify) ? event->subscribe.conn_handle : 0;
        break;
    case BLE_GAP_EVENT_MTU:
        ESP_LOGI(TAG, "MTU updated to %u", event->mtu.value);
        break;
    default:
        break;
    }
    return 0;
}

/* ---------- NimBLE 主机生命周期 ---------- */

static void beminder_on_sync(void)
{
    /* 推断可用的自有地址类型，存下来用于广播 */
    ble_hs_id_infer_auto(0, &s_adv_addr_type);
    ESP_LOGI(TAG, "adv addr type: %u", s_adv_addr_type);
    beminder_start_advertising();
}

static void beminder_host_task(void *param)
{
    (void)param;
    nimble_port_run();
    /* L5：run() 返回（nimble_port_stop 被调用）后必须 deinit，
     * 否则任务函数直接返回属 FreeRTOS 未定义行为。 */
    nimble_port_freertos_deinit();
}

void beminder_ble_init(beminder_state_cb_t on_state)
{
    s_state_cb = on_state;

    int rc = nvs_flash_init();
    if (rc == ESP_ERR_NVS_NO_FREE_PAGES || rc == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        rc = nvs_flash_init();
    }
    if (rc != ESP_OK) {
        /* L6：nvs 初始化失败不应继续，否则后续广播/服务注册状态不可靠 */
        ESP_LOGE(TAG, "nvs init failed: %d", rc);
        return;
    }

    rc = nimble_port_init();
    if (rc != ESP_OK) {
        ESP_LOGE(TAG, "nimble init failed: %d", rc);
        return;
    }

    ble_hs_cfg.sync_cb = beminder_on_sync;

    ble_svc_gap_init();
    ble_svc_gatt_init();

    rc = ble_gatts_count_cfg(beminder_gatt_svcs);
    if (rc != 0) {
        ESP_LOGE(TAG, "gatts count_cfg failed: %d", rc);
        return;
    }
    rc = ble_gatts_add_svcs(beminder_gatt_svcs);
    if (rc != 0) {
        ESP_LOGE(TAG, "gatts add_svcs failed: %d", rc);
        return;
    }

    nimble_port_freertos_init(beminder_host_task);
}

uint8_t beminder_ble_get_state(void)
{
    return beminder_get_state();
}

const char *beminder_state_str(uint8_t state)
{
    switch (state) {
    case BEMINDER_STATE_IDLE:
        return "IDLE";
    case BEMINDER_STATE_ACTIVE:
        return "ACTIVE";
    case BEMINDER_STATE_WARNING:
        return "WARNING";
    case BEMINDER_STATE_CLOSED:
        return "CLOSED";
    default:
        return "UNKNOWN";
    }
}

int beminder_ble_set_closed(void)
{
    bool was_changed = (beminder_get_state() != BEMINDER_STATE_CLOSED);
    beminder_set_state(BEMINDER_STATE_CLOSED);
    if (was_changed && s_state_cb) {
        s_state_cb(BEMINDER_STATE_CLOSED);
    }
    if (s_notify_conn != 0) {
        beminder_notify_state(s_notify_conn);
    }
    return 0;
}