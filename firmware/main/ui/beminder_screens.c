/*
 * beminder_screens.c
 * LVGL 三态屏幕实现。
 *   IDLE    : 待机 Ready
 *   ACTIVE  : 骑行守护中
 *   WARNING : 请检查美团骑行（story-3.1 起在进入时播放声音）
 *   CLOSED  : 已确认
 * 用 LVGL v8 的 obj + label 实现，避免依赖具体的 demo 布局框架，
 * 便于接入 FoloToy 宿主工程的任意容器。
 *
 * 注意：中文与 Emoji 字形需要宿主工程配置包含 CJK 字形的字体，
 * 否则中文会显示为方块。
 */

#include <stdbool.h>

#include "lvgl.h"

#include "beminder_config.h"
#include "beminder_screens.h"

static lv_obj_t *s_parent = NULL;

/* 四个状态各一个可见容器 */
static lv_obj_t *s_screen_idle = NULL;
static lv_obj_t *s_screen_active = NULL;
static lv_obj_t *s_screen_warning = NULL;
static lv_obj_t *s_screen_closed = NULL;

static void obj_show_hide(lv_obj_t *obj, bool show);

static lv_obj_t *make_text_center(const char *text_raw)
{
    lv_obj_t *scr = lv_obj_create(s_parent);
    lv_obj_set_size(scr, LV_PCT(100), LV_PCT(100));
    lv_obj_align(scr, LV_ALIGN_CENTER, 0, 0);

    lv_obj_t *label = lv_label_create(scr);
    lv_label_set_text(label, text_raw);
    lv_obj_align(label, LV_ALIGN_CENTER, 0, 0);

    return scr;
}

void beminder_screens_init(lv_obj_t *parent)
{
    s_parent = parent;

    s_screen_idle = make_text_center("Ready 待机");
    s_screen_active = make_text_center("骑行守护中");
    s_screen_warning = make_text_center("请检查\n美团骑行");
    s_screen_closed = make_text_center("已确认");

    /* 初始只显示 IDLE */
    beminder_screens_show(BEMINDER_STATE_IDLE);
}

void beminder_screens_show(uint8_t state)
{
    if (s_parent == NULL) {
        return;
    }
    obj_show_hide(s_screen_idle, state == BEMINDER_STATE_IDLE);
    obj_show_hide(s_screen_active, state == BEMINDER_STATE_ACTIVE);
    obj_show_hide(s_screen_warning, state == BEMINDER_STATE_WARNING);
    obj_show_hide(s_screen_closed, state == BEMINDER_STATE_CLOSED);
}

static void obj_show_hide(lv_obj_t *obj, bool show)
{
    if (obj == NULL) {
        return;
    }
    if (show) {
        lv_obj_clear_flag(obj, LV_OBJ_FLAG_HIDDEN);
    } else {
        lv_obj_add_flag(obj, LV_OBJ_FLAG_HIDDEN);
    }
}