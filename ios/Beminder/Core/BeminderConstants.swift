//
//  BeminderConstants.swift
//  Beminder
//
//  两端（iPhone App 与 FoloToy 固件）共享的 BLE 协议常量。
//  iPhone 是大脑（Central），FoloToy 是身体（Peripheral）。
//  UUID 与枚举值必须与 firmware/main/beminder_config.h 保持一致。
//

import Foundation
import CoreBluetooth

// MARK: - BLE 服务 / 特征值 UUID

enum BeminderBLE {
    /// Beminder Service，FoloToy 广播，iPhone 扫描
    static let serviceUUID = CBUUID(string: "B3E1F000-0000-1000-8000-00805F9B34FB")

    /// STATE：只读 + Notify。FoloToy 通过它上报当前状态（含按钮 ACK）。取值见 SessionState。
    static let stateUUID = CBUUID(string: "B3E1F001-0000-1000-8000-00805F9B34FB")

    /// COMMAND：可写。iPhone 往这里写入命令驱动 FoloToy。取值见 BLECommand。
    static let commandUUID = CBUUID(string: "B3E1F002-0000-1000-8000-00805F9B34FB")

    /// 设备本地名，用于扫描时过滤 / 用户识别
    static let advertisementName = "Beminder"
}

// MARK: - Session 状态机

/// Guardian 会话状态，与 mvp.md 三状态 + 预留 CLOSED 对应。
/// 原始字节值也用于 BLE 传输（FoloToy STATE 特征值）。
enum SessionState: UInt8 {
    case idle = 0x00       // 没有进行中的 Guardian session
    case active = 0x01     // NFC 触发后，正在守护中
    case warning = 0x02    // 到达 warningTime，进入提醒
    case closed = 0x03     // 用户已按键确认（预留，v0.1 实现）

    var label: String {
        switch self {
        case .idle: return "待机"
        case .active: return "骑行守护中"
        case .warning: return "请检查美团骑行"
        case .closed: return "已确认"
        }
    }
}

// MARK: - iPhone 下发命令

/// 通过 COMMAND 特征值写入的值，驱动 FoloToy 切换页面。
/// v0.1 只需要 START 与 WARNING，RESET 用于手动复位。
enum BLECommand: UInt8 {
    case start = 0x01     // 进入 ACTIVE，FoloToy 显示骑行守护中
    case warning = 0x02   // 进入 WARNING，FoloToy 显示警告并出声
    case reset = 0x03     // 回到 IDLE
}