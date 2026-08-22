/*
 * demo_beminder.c
 * Beminder 固件 demo 入口页。
 *
 * 按 FoloToy 开源工程的 demo 注册机制接入宿主：
 *   - demo_beminder_enter(parent)  进入页面时构建 LVGL 屏幕并启动 BLE 外设
 *   - demo_beminder_exit()         退出页面时停止 BLE、释放屏幕
 *   - demo_beminder_key(...)       按键回调（s32 按钮确认时接入）
 *
 * 职责边界：本文件只做"接线"，把 BLE 收到的状态变化转给屏幕模块。
 * 时间判断全在 iPhone，FoloToy 设身体不自行计时（rfc.md ADR-002）。
 */

#include <string.h>

#include "esp_log.h"

#include "lvgl.h"

#include "beminder_config.h"
#include "beminder_ble.h"
#include "beminder_screens.h"
#include "beminder_audio.h"

/* 宿主 FoloToy 工程通常会 include 一个 demos 注册声明，此处按惯例暴露。
 * 实际接入时，若宿主已有统一的 demo 注册头，改用那个头即可。 */
#include "demos/demo_beminder.h"

static const char *TAG = "demo_beminder";

/* 记录是否有启动的 BLE 外设，防止 enter/exit 交错调用 */
static bool s_ble_started = false;

/* BLE 状态变化回调：把 FoloToy 当前 STATE 转给屏幕与声音 */
static void beminder_on_state(uint8_t state)
{
    ESP_LOGI(TAG, "state received: %u (%s)", state, beminder_state_str(state));
    beminder_screens_show(state);

    /* story-3.1 R3.1.2/R3.1.3/R3.1.4：进入 WARNING 出声并持续直到确认。
     * 离开 WARNING（CLOSED/IDLE）即停止，不自动静音靠持续循环保证。 */
    if (state == BEMINDER_STATE_WARNING) {
        beminder_audio_start_warning();
    } else {
        beminder_audio_stop_warning();
    }
}

/* ---------- FoloToy demo 注册接口 ---------- */

static void demo_beminder_enter(void *param)
{
    lv_obj_t *parent = lv_scr_act();

    if (param != NULL) {
        lv_obj_t *pv = (lv_obj_t *)param;
        if (pv != NULL) {
            parent = pv;
        }
    }

    beminder_screens_init(parent);
    if (!s_ble_started) {
        s_ble_started = true;
        beminder_ble_init(beminder_on_state);
        /* 声音模块：story-3.1 接入 WARNING 提示音。
         * beep_to_host 需要由宿主映射到 FoloToy 实际发声接口。 */
        beminder_audio_init(NULL);
        /* 进入时先按当前状态刷新一次，避免重启后仍显示上次状态 */
        beminder_screens_show(beminder_ble_get_state());
    }
    ESP_LOGI(TAG, "demo entered");
}

static void demo_beminder_enter_event(void *param)
{
    demo_beminder_enter(param);
}

static void demo_beminder_exit(void *param)
{
    /* v0.1 保持 BLE 后台广播（便于 iPhone 随时发现连接），退出页面不关 BLE。
     * 若宿主期望 demo退出即释放资源，可在此调用 ble 停止逻辑并置 s_ble_started=false。
     */
    ESP_LOGI(TAG, "demo exited");
}

static void demo_beminder_key(uint8_t zhkey)
{
    /* story-3.2 接入按钮确认：按下时调用 beminder_ble_set_closed()。
     * zhkey 为宿主按键编码，接入时按实际扫描码分发。
     */
    ESP_LOGI(TAG, "key: %u", zhkey);
}

/* ---------- 注册到宿主 ---------- */

/* 遵循 FoloToy demo 惯例，提供可被宿主 demos 列表引用的实例。
 * 实际接入时按宿主工程的字段命名对齐。 */
const struct ft_demo_s demo_beminder = {
    .name      = BEMINDER_LOCAL_NAME,
    .enter     = demo_beminder_enter_event,
    .exit      = demo_beminder_exit,
    .key       = demo_beminder_key,
};

void reg_beminder(void)
{
    /* FoloToy 宿主通过注册表注册 demo。实际接入时把 demo_beminder 挂到
     * 或传入宿主已有的注册函数表即可，此处保留入口便于查找。 */
    ESP_LOGI(TAG, "registrable demo: %s", demo_beminder.name);
}