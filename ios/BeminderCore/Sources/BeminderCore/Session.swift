//
//  Session.swift
//  BeminderCore
//
//  从 ios/Beminder/Core/Models.swift 剥离纯逻辑而来，去掉了 CoreLocation
//  的 CLLocation 依赖（v0.1 里 P0 只记录不参与判断，见 rfc ADR-006）。
//  绝对时间（startTime / warningTime）是产品可靠性的根基。
//

import Foundation

/// Guardian 会话。持有状态与绝对时间。
struct Session {
    /// 当前状态，原始值即 BLE STATE 特征值
    var state: SessionState = .idle

    /// NFC 触发时间（绝对时间）
    var startTime: Date?

    /// 应进入提醒的时间（绝对时间）= startTime + timeout
    var warningTime: Date?

    /// 当前是否正在守护（ACTIVE 或 WARNING）
    var isGuarding: Bool {
        state == .active || state == .warning
    }

    /// 剩余时间（秒）。由绝对时间重算，不依赖倒计时任务。
    func remainingSeconds(at now: Date) -> TimeInterval {
        guard let warningTime else { return 0 }
        return max(0, warningTime.timeIntervalSince(now))
    }
}