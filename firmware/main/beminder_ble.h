/*
 * beminder_ble.h
 * FoloToy BLE 外设：广播 Beminder Service，接收 iPhone 写入的命令。
 *
 * FoloToy 设身体（BLE Peripheral），iPhone 设大脑（BLE Central）。
 * 本模块只负责收发 BLE，不计算时间、不做判断，判断全在 iPhone。
 */

#ifndef BEMINDER_BLE_H
#define BEMINDER_BLE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* 状态变化回调：UI 模块据此切换屏幕。state 取值见 beminder_config.h：
 * BEMINDER_STATE_* */
typedef void (*beminder_state_cb_t)(uint8_t state);

/* 初始化 BLE 外设。传入 UI 模块的状态回调。 */
void beminder_ble_init(beminder_state_cb_t on_state);

/* 供按钮确认使用：把 STATE 置为 CLOSED 并 Notify 给 iPhone（story-3.2）。 */
int beminder_ble_set_closed(void);

/* 读取当前 STATE。 */
uint8_t beminder_ble_get_state(void);

/* 返回 STATE 的可读名称，用于日志。取值见 beminder_config.h 的 BEMINDER_STATE_*。 */
const char *beminder_state_str(uint8_t state);

#ifdef __cplusplus
}
#endif

#endif /* BEMINDER_BLE_H */