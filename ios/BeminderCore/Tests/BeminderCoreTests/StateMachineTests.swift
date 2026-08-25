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

    // MARK: - M15 补齐关键转移覆盖

    @Test("ACTIVE 下 ack 进入 CLOSED")
    func ackFromActiveToClosed() {
        var s = Session(state: .active, startTime: t0, warningTime: t0.addingTimeInterval(30))

        machine.ack(session: &s)

        #expect(s.state == .closed)
    }

    @Test("IDLE 下 ack 被忽略（M14 收紧，不产出双 nil 时间的 CLOSED）")
    func ackFromIdleIgnored() {
        var s = Session(state: .idle)

        machine.ack(session: &s)

        #expect(s.state == .idle)
        #expect(s.startTime == nil)
        #expect(s.warningTime == nil)
    }

    @Test("CLOSED 下 ack 幂等保持 CLOSED")
    func ackFromClosedNoop() {
        var s = Session(state: .closed)

        machine.ack(session: &s)

        #expect(s.state == .closed)
    }

    @Test("WARNING 下 recompute 保持 WARNING（不再回退）")
    func recomputeInWarningHolds() {
        var s = Session(state: .warning, startTime: t0, warningTime: t0.addingTimeInterval(30))

        machine.recompute(session: &s, now: t0.addingTimeInterval(9999))

        #expect(s.state == .warning)
    }

    @Test("CLOSED 下 recompute 空操作")
    func recomputeInClosedIsNoop() {
        var s = Session(state: .closed, startTime: t0, warningTime: t0.addingTimeInterval(30))

        machine.recompute(session: &s, now: t0.addingTimeInterval(9999))

        #expect(s.state == .closed)
    }

    @Test("WARNING 下 start 被忽略（守护中重复触发防护）")
    func startIgnoredInWarning() {
        var s = Session(state: .warning, startTime: t0, warningTime: t0.addingTimeInterval(30))

        machine.start(session: &s, now: t0.addingTimeInterval(10))

        #expect(s.state == .warning)
        #expect(s.warningTime == t0.addingTimeInterval(30)) // 时间未被改写
    }

    @Test("CLOSED 下 start 允许重开新会话")
    func startRestartsAfterClosed() {
        var s = Session(state: .closed, startTime: t0, warningTime: t0.addingTimeInterval(30))
        let t1 = t0.addingTimeInterval(100)

        machine.start(session: &s, now: t1)

        #expect(s.state == .active)
        #expect(s.startTime == t1)
        #expect(s.warningTime == t1.addingTimeInterval(30))
    }

    @Test("reset 从四个起始状态都回到 IDLE 并清空时间戳")
    func resetReturnsToIdleFromAnyState() {
        for state in [SessionState.idle, .active, .warning, .closed] {
            var s = Session(state: state, startTime: t0, warningTime: t0.addingTimeInterval(30))

            machine.reset(session: &s)

            #expect(s.state == .idle)
            #expect(s.startTime == nil)
            #expect(s.warningTime == nil)
        }
    }
}