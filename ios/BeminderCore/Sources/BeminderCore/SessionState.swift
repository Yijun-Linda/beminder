//
//  SessionState.swift
//  BeminderCore
//
//  从 ios/Beminder/Core/BeminderConstants.swift 中剥离纯逻辑而来。
//  原始字节值同时用于 FoloToy 固件的 BLE STATE 特征值，必须保持一致。
//

/// Guardian 会话状态，与 mvp.md 三状态 + 预留 CLOSED 对应。
enum SessionState: UInt8 {
    /// 没有进行中的 Guardian session
    case idle = 0x00
    /// NFC 触发后，正在守护中
    case active = 0x01
    /// 到达 warningTime，进入提醒
    case warning = 0x02
    /// 用户已按键确认
    case closed = 0x03

    var label: String {
        switch self {
        case .idle: return "待机"
        case .active: return "骑行守护中"
        case .warning: return "请检查美团骑行"
        case .closed: return "已确认"
        }
    }
}