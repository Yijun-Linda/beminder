/*
 * demo_beminder.h
 * Beminder 固件 demo 入口声明。
 *
 * 提供 FoloToy 宿主可引用的 demo 实例（enter / exit / key 三接口）与注册入口。
 * 接入 FoloToy 开源工程时，把 demo_beminder 挂到宿主 demos 注册表。
 */

#ifndef DEMO_BEMINDER_H
#define DEMO_BEMINDER_H

#ifdef __cplusplus
extern "C" {
#endif

/* 与 FoloToy 宿主约定的 demo 结构体（含回调函数指针）。
 * 若宿主的官方结构体字段不同，接入时来源字段名对齐即可，函数签名保持不变。 */
struct ft_demo_s {
    const char *name;
    void (*enter)(void *param);
    void (*exit)(void *param);
    void (*key)(uint8_t key);
};

/* 可被宿主注册表引用的 demo 实例 */
extern const struct ft_demo_s demo_beminder;

/* 注册入口，宿主在初始化阶段调用 */
void reg_beminder(void);

#ifdef __cplusplus
}
#endif

#endif /* DEMO_BEMINDER_H */