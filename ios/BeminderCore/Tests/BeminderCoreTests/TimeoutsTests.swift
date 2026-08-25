//
//  TimeoutsTests.swift
//  BeminderCoreTests
//

import Testing
import Foundation
@testable import BeminderCore

@Suite("超时参数", .serialized)
struct TimeoutsTests {

    // 本套件会改动全局 currentMode，.serialized 保证串行执行，避免与
    // StateMachineTests 等其它修改全局态的套件交错产生偶发失败（M16）。

    @Test("默认模式是 .development（与宿主 ios/Beminder/Core/Timeouts.swift 镜像对齐，H4）")
    func defaultModeIsDevelopment() {
        // H4 镜像断言：BeminderCore 的默认 currentMode 必须与宿主 App 副本一致
        // （都是 .development，30 秒），否则包被宿主引用时开发期超时会静默漂移成 35 分钟。
        if case .production = TimeoutsConfig.currentMode {
            Issue.record("默认 currentMode 不应是 .production，必须与宿主保持 .development")
        }
        #expect(TimeoutsConfig.timeout == 30)
    }

    @Test("development 模式为 30 秒")
    func developmentTimeoutIs30Seconds() {
        TimeoutsConfig.currentMode = .development
        #expect(TimeoutsConfig.timeout == 30)
        #expect(TimeoutsConfig.developmentSeconds == 30)
    }

    @Test("production 模式为 35 分钟（2100 秒）")
    func productionTimeoutIs35Minutes() {
        TimeoutsConfig.currentMode = .production
        #expect(TimeoutsConfig.timeout == 35 * 60)
        #expect(TimeoutsConfig.productionMinutes == 35)
    }
}