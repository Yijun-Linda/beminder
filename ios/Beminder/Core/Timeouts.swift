//
//  Timeouts.swift
//  Beminder
//
//  超时参数。开发用 30 秒测试模式，正式用 35 分钟生产模式。
//  其他地方只切换 currentMode，不改任何架构（见 rfc ADR-004）。
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
    /// 2026-08-25：开发阶段保持 30 秒测试模式（rfc ADR-004）。
    static var currentMode: GuardianMode = .development

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