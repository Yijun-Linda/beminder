//
//  SessionManager.swift
//  Beminder
//
//  iPhone 是大脑：持有会话状态、绝对时间、是否进入 WARNING 的判断。
//  story-1.1 实现 NFC 触发的启动仪式；story-1.2 加上绝对时间状态机。
//

import Foundation
import Combine
import UIKit
import CoreLocation

/// Guardian 会话管理器。
/// 采用 @Published 状态 + NotificationCenter 广播，UI 与 BLE 同步都订阅状态变化。
final class SessionManager: ObservableObject {
    static let shared = SessionManager()

    @Published private(set) var session = BeminderSession()

    /// 当前是否正在守护（ACTIVE 或 WARNING）
    var isGuarding: Bool {
        session.state == .active || session.state == .warning
    }

    private let locationManager = LocationManager()
    private let bleManager = BLEManager.shared
    private let defaults = UserDefaults.standard

    /// 应用内 NFC 扫描器。仅在有 CoreNFC 的平台可用（编译守卫见 NFCManager.swift）；
    /// 无 CoreNFC 平台为占位实现，保证本类引用可编译。
    #if canImport(CoreNFC)
    private let nfcManager = NFCManager()
    #endif

    /// 轻量驱动：周期性重算绝对时间（重新评估 now vs warningTime），
    /// 不是倒计时程序，不持有任何计时状态（rfc ADR-002 / story-1.2 R1.2.6）。
    private var recomputeTimer: Timer?

    private init() {
        restore()
        observeLifecycle()
        observeLocation()
        observeNFC()
        observeFoloToyConnection()
        observeFoloToy()
        if isGuarding {
            startRecomputeTimer()
        }
    }

    // MARK: - 入口

    /// 统一启动入口。source 是事件来源（manual / shortcut / nfc），只用于记录，
    /// 不参与状态机逻辑。story-1.1 不涉及 BLE。
    func start(from source: SessionStartSource) {
        guard !isGuarding else { return }   // 已有进行中的会话则忽略重复触发

        let now = Date()
        session.startTime = now
        session.warningTime = now.addingTimeInterval(TimeoutsConfig.timeout)
        setState(.active)

        locationManager.requestCurrentLocation()

        // 可见通知：Beminder 已启动（需先在启动态请求通知权限）
        NotificationHelper.fireStarted(source: source)
        // 到点提醒：绝对时间调度本地通知作为兜底（App 后台也能收到）
        NotificationHelper.scheduleWarning(at: session.warningTime)
        startRecomputeTimer()
        persist()
        NSLog("Beminder started via %@ at %@", source.rawValue, "\(now)")
    }

    // MARK: - 状态重算（story-1.2 核心）

    /// 用绝对时间判断是否需要进入 WARNING。
    /// 与 now >= warningTime 比较，不依赖任何倒计时程序。
    func recomputeStateIfNeeded() {
        guard isGuarding, let warningTime = session.warningTime else { return }
        if Date() >= warningTime, session.state == .active {
            setState(.warning)
            persist()
            // 兜底：前台时也弹一次可见提醒
            NotificationHelper.fireWarningIfActive()
        }
    }

    /// 供 App 从后台/重启恢复后调用（见 dev 文档，iOS 生命周期）。
    func resume() {
        restore()               // 从持久化恢复最近一次会话
        recomputeStateIfNeeded() // 重算 remaining = warningTime - now，状态仍正确
    }

    // MARK: - URL scheme 入口（Shortcut 唤起）

    /// 处理 Shortcut 通过 URL scheme 唤起。scheme 见 Info.plist 的 CFBundleURLTypes。
    func handleLaunch(url: URL) {
        guard let scheme = url.scheme?.lowercased(), scheme == "beminder" else { return }
        start(from: .shortcut)
    }

    // MARK: - 手动 NFC 扫描（开发 / 备用入口）

    #if canImport(CoreNFC)
    func startForegroundScan() {
        nfcManager.startScan { [weak self] in
            self?.start(from: .nfc)
        }
    }
    #endif

    // MARK: - 内部

    private func setState(_ newState: SessionState) {
        guard newState != session.state else { return }
        session.state = newState
        // 只下发 iPhone 算出的可驱动状态（active/warning）；idle/closed 由 reset 或 ACK 处理
        if newState == .active || newState == .warning {
            bleManager.send(state: newState)
        }
        NotificationCenter.default.post(name: .sessionStateDidChange, object: session)
    }

    // MARK: 持久化（App 被后台终止后可恢复，配合绝对时间重算）

    private enum Keys {
        static let state = "beminder.session.state"
        static let startTime = "beminder.session.startTime"
        static let warningTime = "beminder.session.warningTime"
    }

    private func persist() {
        defaults.set(session.state.rawValue, forKey: Keys.state)
        defaults.set(session.startTime?.timeIntervalSince1970, forKey: Keys.startTime)
        defaults.set(session.warningTime?.timeIntervalSince1970, forKey: Keys.warningTime)
    }

    private func restore() {
        guard defaults.object(forKey: Keys.state) != nil else { return }
        let stateRaw = defaults.integer(forKey: Keys.state)
        let session_ = BeminderSession(
            state: SessionState(rawValue: UInt8(stateRaw)) ?? .idle,
            startTime: (defaults.object(forKey: Keys.startTime) as? TimeInterval).flatMap { Date(timeIntervalSince1970: $0) },
            warningTime: (defaults.object(forKey: Keys.warningTime) as? TimeInterval).flatMap { Date(timeIntervalSince1970: $0) }
        )
        session = session_
        if isGuarding {
            startRecomputeTimer()
        }
    }

    // MARK: iOS 生命周期

    private func observeLifecycle() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.resume()
        }
    }

    private func startRecomputeTimer() {
        guard recomputeTimer == nil else { return }
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.recomputeStateIfNeeded()
        }
        RunLoop.main.add(timer, forMode: .common)
        recomputeTimer = timer
    }

    private func stopRecomputeTimer() {
        recomputeTimer?.invalidate()
        recomputeTimer = nil
    }

    private func observeLocation() {
        NotificationCenter.default.addObserver(
            forName: .locationDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let loc = note.object as? CLLocation else { return }
            // P0 只记录不参与判断（rfc ADR-006）
            self?.session.startLocation = loc
        }
    }

    private func observeNFC() {
        // 预留：后续版本 NFC 确认（v0.3）走这里
    }

    /// 把 BLE 连接状态同步到会话模型（R2.2.5：连接断开时更新连接状态）。
    private func observeFoloToyConnection() {
        NotificationCenter.default.addObserver(
            forName: .foloToyConnectionDidChange,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self = self, let connected = note.object as? Bool else { return }
            self.session.foloToyConnected = connected
            NotificationCenter.default.post(name: .sessionStateDidChange, object: self.session)
        }
    }

    private func observeFoloToy() {
        // FoloToy 反向上报（按钮确认 CLOSED），回写到 Session 并广播给 UI。
        // story-3.2 接入按钮 ACK；这里先让连接与反向通道保持接通。
        NotificationCenter.default.addObserver(
            forName: .foloToyStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self = self else { return }
            guard let state = note.object as? SessionState else { return }
            if state == .closed {
                self.stopRecomputeTimer()
                self.session.state = state
                persist()
                NotificationCenter.default.post(name: .sessionStateDidChange, object: session)
            }
        }
    }
}

// MARK: - 测试 / 调试辅助

#if DEBUG
extension SessionManager {
    /// 仅供开发：手动复位到 IDLE
    func debugReset() {
        stopRecomputeTimer()
        session = BeminderSession()
        defaults.removeObject(forKey: Keys.state)
        defaults.removeObject(forKey: Keys.startTime)
        defaults.removeObject(forKey: Keys.warningTime)
        NotificationCenter.default.post(name: .sessionStateDidChange, object: session)
    }
}
#endif