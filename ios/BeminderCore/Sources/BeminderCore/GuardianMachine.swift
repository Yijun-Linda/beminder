//
//  GuardianMachine.swift
//  BeminderCore
//
//  从 ios/Beminder/Core/SessionManager.swift 剥离的状态迁移规则，去掉
//  UIKit / Combine / Timer / UserDefaults 等平台依赖，改成注入 now 的
//  纯函数，便于在 Windows 上用 swift test 验证绝对时间状态机。
//
//  迁移规则与原始 SessionManager 保持一致：
//  - start：非守护中才启动，warningTime = startTime + timeout
//  - recompute：ACTIVE 且 now >= warningTime 进入 WARNING（绝对时间，不倒计时）
//  - ack：收到按钮确认进入 CLOSED
//  - reset：回到 IDLE
//

import Foundation

/// 状态机纯逻辑。所有时间点由调用方显式注入，保证测试确定性。
struct GuardianMachine {

    /// NFC / URL 触发后的统一启动入口。已在守护中则忽略重复触发。
    func start(session: inout Session, now: Date) {
        guard !session.isGuarding else { return }

        session.startTime = now
        session.warningTime = now.addingTimeInterval(TimeoutsConfig.timeout)
        session.state = .active
    }

    /// 用绝对时间判断是否需要进入 WARNING。
    /// 与 now >= warningTime 比较，不依赖任何倒计时程序。
    func recompute(session: inout Session, now: Date) {
        guard session.isGuarding, let warningTime = session.warningTime else { return }
        if now >= warningTime, session.state == .active {
            session.state = .warning
        }
    }

    /// 按钮确认收到 ACK，结束守护会话。
    /// M14：仅在守护中（ACTIVE / WARNING）接受 ACK。无会话的 IDLE 收到 ACK
    /// 若直接进入 CLOSED，会产生双 nil 时间戳的"已确认"态，与注释语义矛盾，
    /// 也与固件"仅 WARNING 下确认"的语义不对称。乱序/误触一律忽略。
    func ack(session: inout Session) {
        guard session.isGuarding else { return }
        session.state = .closed
    }

    /// 手动复位到 IDLE。
    func reset(session: inout Session) {
        session = Session()
    }
}