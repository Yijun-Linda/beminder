//
//  StateMachineTests.swift
//  BeminderCoreTests
//

import Testing
import Foundation
@testable import BeminderCore

@Suite("绝对时间状态机")
struct StateMachineTests {

    private let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    private let machine = GuardianMachine()

    @Test("idle 下 start 进入 ACTIVE，warningTime = startTime + timeout")
    func startMovesIdleToActive() {
        TimeoutsConfig.currentMode = .development
        var s = Session(state: .idle)

        machine.start(session: &s, now: t0)

        #expect(s.state == .active)
        #expect(s.startTime == t0)
        #expect(s.warningTime == t0.addingTimeInterval(30))
        #expect(s.isGuarding)
    }

    @Test("已在守护中时 start 被忽略（重复触发防护）")
    func startIgnoredWhileGuarding() {
        var s = Session(state: .active)
        let before = s

        machine.start(session: &s, now: t0)
        machine.start(session: &s, now: t0.addingTimeInterval(5))

        // 不应在 ACTIVE 基础上再次改写时间或状态
        #expect(s.state == .active)
        #expect(s.startTime == before.startTime)
        #expect(s.warningTime == before.warningTime)
    }

    @Test("before warningTime 时 recompute 保持 ACTIVE")
    func recomputeBeforeDeadlineKeepsActive() {
        var s = Session(state: .active, startTime: t0, warningTime: t0.addingTimeInterval(30))

        machine.recompute(session: &s, now: t0.addingTimeInterval(10))

        #expect(s.state == .active)
    }

    @Test("到达 warningTime 时 recompute 进入 WARNING")
    func recomputeAtDeadlineEntersWarning() {
        var s = Session(state: .active, startTime: t0, warningTime: t0.addingTimeInterval(30))

        machine.recompute(session: &s, now: t0.addingTimeInterval(30))

        #expect(s.state == .warning)
    }

    @Test("超过 warningTime 时 recompute 进入 WARNING")
    func recomputeAfterDeadlineEntersWarning() {
        var s = Session(state: .active, startTime: t0, warningTime: t0.addingTimeInterval(30))

        machine.recompute(session: &s, now: t0.addingTimeInterval(60))

        #expect(s.state == .warning)
    }

    @Test("idle 状态下 recompute 不进入 WARNING")
    func recomputeInIdleIsNoop() {
        var s = Session(state: .idle)

        machine.recompute(session: &s, now: t0.addingTimeInterval(9999))

        #expect(s.state == .idle)
    }

    @Test("ACK 将会话置为 CLOSED")
    func ackMovesToClosed() {
        var s = Session(state: .warning, startTime: t0, warningTime: t0.addingTimeInterval(60))

        machine.ack(session: &s)

        #expect(s.state == .closed)
        #expect(!s.isGuarding)
    }

    @Test("remainingSeconds 计算剩余时间并钳制到非负")
    func remainingSecondsClampedNonNegative() {
        let warning = t0.addingTimeInterval(30)

        // 剩 20 秒
        #expect(Session(state: .active, warningTime: warning).remainingSeconds(at: t0.addingTimeInterval(10)) == 20)
        // 已过期 -> 0
        #expect(Session(state: .warning, warningTime: warning).remainingSeconds(at: t0.addingTimeInterval(60)) == 0)
        // 无 warningTime -> 0
        #expect(Session(state: .idle).remainingSeconds(at: t0) == 0)
    }

    @Test("development 模式端到端：start -> 30秒后 WARNING -> ACK -> CLOSED")
    func devEndToEndFlow() {
        TimeoutsConfig.currentMode = .development
        var s = Session(state: .idle)

        machine.start(session: &s, now: t0)
        #expect(s.state == .active)

        // 未到点仍是 active
        machine.recompute(session: &s, now: t0.addingTimeInterval(20))
        #expect(s.state == .active)

        // 到点进入 warning
        machine.recompute(session: &s, now: t0.addingTimeInterval(30))
        #expect(s.state == .warning)

        // 按钮确认关闭
        machine.ack(session: &s)
        #expect(s.state == .closed)
    }
}