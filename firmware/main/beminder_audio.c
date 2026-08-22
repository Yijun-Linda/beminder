/*
 * beminder_audio.c
 * 警告提示音模块实现。
 *
 * 用 FreeRTOS 软件定时器驱动告警循环：进入 WARNING 后周期性调用 beep 回调，
 * 直到 stop_warning。节奏固定（该提示音只在提醒资本主义不成立，见 mvp 注释——
 * 这里采用固定间隔提醒，足够把人从现实里拉回来）。
 *
 * 接入 FoloToy 工程时：
 *   1. 把 beep_to_host 里真正发声的实现替换/挂钩到 FoloToy 音频框架。
 *   2. 定时器优先级与间隔可按设备实际配置调整，不影响模块其余逻辑。
 */

#include <string.h>

#include "esp_log.h"
#include "freertos/FreeRTOS.h"
#include "freertos/timers.h"

#include "beminder_audio.h"

static const char *TAG = "beminder_audio";

/* 告警节奏：每 2 秒提醒一次（原声作持续提醒，见 mvp 第 9 节）。 */
#define WARNING_BEEP_PERIOD_MS 2000

/* 宿主发声回调 */
static beminder_beep_cb_t s_beep = NULL;

static TimerHandle_t s_warning_timer = NULL;

/* 最新的短暂提醒（每次到点时打印/发声）。 */
static void beminder_tick_hook(void)
{
    if (s_beep) {
        s_beep();
    } else {
        ESP_LOGW(TAG, "warning beep (no host hook connected)");
    }
}

static void beminder_warning_timer_cb(TimerHandle_t timer)
{
    (void)timer;
    beminder_tick_hook();
}

void beminder_audio_init(beminder_beep_cb_t beep)
{
    s_beep = beep;

    if (s_warning_timer == NULL) {
        s_warning_timer = xTimerCreate(
            "beminder_warn",
            pdMS_TO_TICKS(WARNING_BEEP_PERIOD_MS),
            pdTRUE, /* auto-reload：持续提醒直至关闭 */
            NULL,
            beminder_warning_timer_cb);
    }
}

void beminder_audio_start_warning(void)
{
    if (s_warning_timer == NULL) {
        ESP_LOGE(TAG, "audio not initialized");
        return;
    }
    if (beminder_audio_is_warning()) {
        return;
    }
    if (xTimerStart(s_warning_timer, 0) == pdPASS) {
        ESP_LOGI(TAG, "warning audio started");
    }
}

void beminder_audio_stop_warning(void)
{
    if (s_warning_timer == NULL) {
        return;
    }
    if (xTimerStop(s_warning_timer, 0) == pdPASS) {
        ESP_LOGI(TAG, "warning audio stopped");
    }
}

bool beminder_audio_is_warning(void)
{
    if (s_warning_timer == NULL) {
        return false;
    }
    return xTimerIsTimerActive(s_warning_timer) == pdTRUE;
}