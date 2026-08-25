/*
 * beminder_config.h
 * FoloToy 侧 Beminder 共享配置。
 *
 * iPhone 设大脑（BLE Central），FoloToy 设身体（BLE Peripheral）。
 * 本文件的 UUID 与枚举值必须与 ios/Beminder/Core/BeminderConstants.swift
 * 保持一致，否则两端将无法发现对方。
 */

#ifndef BEMINDER_CONFIG_H
#define BEMINDER_CONFIG_H

/* ---------- BLE 服务 / 特征值 UUID（小端字节序） ---------- */
/* 服务:     B3E1F000-0000-1000-8000-00805F9B34FB */
/* STATE:    B3E1F001-0000-1000-8000-00805F9B34FB (Read + Notify) */
/* COMMAND:  B3E1F002-0000-1000-8000-00805F9B34FB (Write) */

#define BEMINDER_SERVICE_UUID \
    0xFB, 0x34, 0x9B, 0x5F, 0x80, 0x00, 0x00, 0x80, \
    0x00, 0x10, 0x00, 0x00, 0x00, 0xF0, 0xE1, 0xB3

#define BEMINDER_STATE_UUID \
    0xFB, 0x34, 0x9B, 0x5F, 0x80, 0x00, 0x00, 0x80, \
    0x00, 0x10, 0x00, 0x00, 0x01, 0xF0, 0xE1, 0xB3

#define BEMINDER_COMMAND_UUID \
    0xFB, 0x34, 0x9B, 0x5F, 0x80, 0x00, 0x00, 0x80, \
    0x00, 0x10, 0x00, 0x00, 0x02, 0xF0, 0xE1, 0xB3

/* ---------- STATE 特征值取值（与 iOS SessionState 对应） ---------- */
#define BEMINDER_STATE_IDLE     0x00
#define BEMINDER_STATE_ACTIVE   0x01
#define BEMINDER_STATE_WARNING  0x02
#define BEMINDER_STATE_CLOSED   0x03

/* ---------- COMMAND 特征值取值（与 iOS BLECommand 对应） ---------- */
#define BEMINDER_CMD_START      0x01
#define BEMINDER_CMD_WARNING    0x02
#define BEMINDER_CMD_RESET      0x03

/* 广播设备本地名，扫描时用于识别 */
#define BEMINDER_LOCAL_NAME     "Beminder"

/* 按钮 1（处理）的按键码。接入 FoloToy 工程时按实际扫码映射到确认键。
 * 只有按下配置为确认的按键且处于 WARNING 时才发 ACK（story-3.2 R3.2.1/R3.2.5）。 */
#define BEMINDER_KEY_CONFIRM    1

/* STATE Notify 支持的最大并发订阅 Central 数（L7 多订阅者跟踪用）。
 * 产品通常只有一个 iPhone 作为 Central，留 ≥2 防止第二位连接覆盖首订阅者。 */
#define BEMINDER_MAX_SUBSCRIBERS 4

/*
 * M11 安全姿势（发布前必须知悉，勿当作已启用安全）：
 * 全链路 BLE 通信无配对、绑定与加密。射程内任意 Central 可读 STATE、伪造
 * START/WARNING，更可直接写 RESET 远程关闭正在响的警告音，恰好绕过
 * "未确认不得自动静音"的产品约束。
 * - 现状：工程尚未启用 LE Secure Connections / 配对 / 白名单。这是当前量级
 *   （开发验证 / 个人骑行守护）可接受的开放风险，但发布前需评估。
 * - 缓解候选：至少对 COMMAND 写入要求加密（encrypted write）或白名单过滤；
 *   对 STATE 通知开启 authenticated/secure 属性。列入后续加固项。
 */

#endif /* BEMINDER_CONFIG_H */