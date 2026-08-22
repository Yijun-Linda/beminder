/*
 * beminder_audio.h
 * 警告提示音模块。
 *
 * 职责：进入 WARNING 后按固定节奏循环播放提示音，直到用户确认（进入 CLOSED）。
 * 真正的音频播放由宿主 FoloToy 工程提供（beep 回调在接入时挂钩）。
 *
 * 约束：声音是持续提醒而非一次性通知（mvp 第 9 节 / story-3.1 R3.1.2 / R3.1.3 / R3.1.4），
 * 未确认不得自动静音。
 */

#ifndef BEMINDER_AUDIO_H
#define BEMINDER_AUDIO_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* 宿主提供的播一次短音（beep）的回调。接入 FoloToy 工程时映射到其音频框架。 */
typedef void (*beminder_beep_cb_t)(void);

/* 初始化音频模块。beep 为宿主实际发声回调；若为 NULL 则只打印日志不发声。 */
void beminder_audio_init(beminder_beep_cb_t beep);

/* 开始循环警告提示音（进入 WARNING 时调用）。重复调用无副作用。 */
void beminder_audio_start_warning(void);

/* 停止警告提示音（用户确认 CLOSED 时调用）。 */
void beminder_audio_stop_warning(void);

/* 当前是否在告警循环中。 */
bool beminder_audio_is_warning(void);

#ifdef __cplusplus
}
#endif

#endif /* BEMINDER_AUDIO_H */