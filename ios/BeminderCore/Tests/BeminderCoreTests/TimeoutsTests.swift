//
//  TimeoutsTests.swift
//  BeminderCoreTests
//

import Testing
import Foundation
@testable import BeminderCore

@Suite("超时参数")
struct TimeoutsTests {

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