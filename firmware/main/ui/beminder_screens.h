/*
 * beminder_screens.h
 * LVGL 展示模块：根据 FoloToy 当前 STATE 切换屏幕内容。
 * 只追求极简地显示状态文本，不做复杂动效，见对应迭代文档。
 */

#ifndef BEMINDER_SCREENS_H
#define BEMINDER_SCREENS_H

#include "lvgl.h"

#ifdef __cplusplus
extern "C" {
#endif

/* 在 parent 容器下构建 Beminder 三态屏幕（READY / ACTIVE / WARNING）。 */
void beminder_screens_init(lv_obj_t *parent);

/* 按状态切换显示。state 取值见 beminder_config.h 的 BEMINDER_STATE_*。 */
void beminder_screens_show(uint8_t state);

#ifdef __cplusplus
}
#endif

#endif /* BEMINDER_SCREENS_H */