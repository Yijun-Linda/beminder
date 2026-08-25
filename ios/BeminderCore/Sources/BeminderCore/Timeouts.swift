//
//  Timeouts.swift
//  BeminderCore
//
//  从 ios/Beminder/Core/Timeouts.swift 原样抽取，纯 Foundation，无平台依赖。
//  开发用 30 秒测试模式，正式 35 分钟生产模式。
//
//  ⚠️ H4 一致性约束：本文件与 ios/Beminder/Core/Timeouts.swift 互为镜像，
//  任何超时值或默认模式的改动必须两端同步，否则会出现"开发期 30 秒静默变成
//  35 分钟"的漂移。默认统一为 .development（与宿主 App 保持一致），
//  TimeoutsTests 里加了镜像断言以捕获漂移。
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
    /// 默认统一为 .development（与宿主 App 的 ios/Beminder/Core/Timeouts.swift 一致，
    /// 避免包被宿主引用时开发期超时静默变成 35 分钟）。
    static nonisolated(unsafe) var currentMode: GuardianMode = .development

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