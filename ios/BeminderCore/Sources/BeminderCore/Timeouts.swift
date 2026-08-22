//
//  Timeouts.swift
//  BeminderCore
//
//  从 ios/Beminder/Core/Timeouts.swift 原样抽取，纯 Foundation，无平台依赖。
//  开发用 30 秒测试模式，正式 35 分钟生产模式。
//

import Foundation

/// Guardian 运行模式，决定超时时长。
enum GuardianMode {
    /// 开发 / 测试模式：30 秒，便于调试闭环
    case development
    /// 生产模式：35 分钟
    case production
}

/// 超时参数集中在这里。值对应 .env.example 里的
/// DEVELOPMENT_TIMEOUT_SECONDS / PRODUCTION_TIMEOUT_MINUTES。
enum TimeoutsConfig {
    static let developmentSeconds: TimeInterval = 30
    static let productionMinutes: TimeInterval = 35

    /// 当前生效模式。story-3.2 闭环跑通后切到生产模式（35 分钟）。
    /// Swift 6 严格并发下全局可变配置用 nonisolated(unsafe) 显式声明非隔离，
    /// 语义与原版本一致，仅适配编译器并发安全检查。
    static nonisolated(unsafe) var currentMode: GuardianMode = .production

    /// 当前模式对应的超时时长（秒）
    static var timeout: TimeInterval {
        switch currentMode {
        case .development:
            return developmentSeconds
        case .production:
            return productionMinutes * 60
        }
    }
}