//
//  Models.swift
//  Beminder
//
//  Guardian 会话的数据模型。iPhone 是唯一的时间权威，
//  这里的绝对时间（startTime / warningTime）是整个产品可靠性的根基。
//

import Foundation
import CoreLocation

/// Guardian 会话。持有状态、绝对时间与启动位置 P0。
struct BeminderSession {
    /// 当前状态，原始值即 BLE STATE 特征值（见 BeminderConstants）
    var state: SessionState = .idle

    /// NFC 触发时间（绝对时间）
    var startTime: Date?

    /// 应进入提醒的时间（绝对时间）= startTime + timeout
    var warningTime: Date?

    /// 启动位置 P0。v0.1 只记录不参与判断（rfc ADR-006），留给 v0.2 人车分离。
    var startLocation: CLLocation?

    /// FoloToy BLE 连接状态（v0.1 显示用，见 dev2）
    var foloToyConnected = false

    /// 剩余时间（秒）。由绝对时间重算，不依赖倒计时任务。
    var remainingSeconds: TimeInterval {
        guard let warningTime else { return 0 }
        return max(0, warningTime.timeIntervalSinceNow)
    }
}

// MARK: - 通知中心事件名

extension Notification.Name {
    /// 会话状态发生变化。FoloToy 同步与 UI 刷新监听该事件。
    static let sessionStateDidChange = Notification.Name("beminder.sessionStateDidChange")
    /// 当前位置更新（P0 获取）
    static let locationDidUpdate = Notification.Name("beminder.locationDidUpdate")
    /// FoloToy 反向上报的状态（如按钮确认 CLOSED）。object 为 SessionState。
    static let foloToyStateDidChange = Notification.Name("beminder.foloToyStateDidChange")
    /// FoloToy 连接状态变化。object 为 Bool（是否已连接）。
    static let foloToyConnectionDidChange = Notification.Name("beminder.foloToyConnectionDidChange")
}