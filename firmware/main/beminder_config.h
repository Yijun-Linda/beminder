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

/* ---------- STATE 特征值取-（与 iOS SessionState 对应） ---------- */
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

#endif /* BEMINDER_CONFIG_H */