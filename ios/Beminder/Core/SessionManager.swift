//
//  SessionManager.swift
//  Beminder
//
//  iPhone 是大脑：持有会话状态、绝对时间、是否进入 WARNING 的判断。
//  story-1.1 实现 NFC 触发的启动仪式；story-1.2 加上绝对时间状态机。
//

import Foundation
import Combine
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
    private let nfcManager = NFCManager()

    private init() {
        observeLocation()
        observeNFC()
    }

    // MARK: - 入口

    /// NFC 触发后的统一启动入口。story-1.1 不涉及 BLE。
    func start(from source: String) {
        guard !isGuarding else { return }   // 已有进行中的会话则忽略重复触发

        let now = Date()
        session.startTime = now
        session.warningTime = now.addingTimeInterval(TimeoutsConfig.timeout)
        setState(.active)

        locationManager.requestCurrentLocation()

        // 可见通知：Beminder 已启动（需先在启动态请求通知权限）
        NotificationHelper.fireStarted(source: source)
        NSLog("Beminder started via %@ at %@", source, "\(now)")
    }

    // MARK: - URL scheme 入口（Shortcut 唤起）

    /// 处理 Shortcut 通过 URL scheme 唤起。scheme 见 Info.plist 的 CFBundleURLTypes。
    func handleLaunch(url: URL) {
        guard let scheme = url.scheme?.lowercased(), scheme == "beminder" else { return }
        start(from: "shortcut")
    }

    // MARK: - 手动 NFC 扫描（开发 / 备用入口）

    func startForegroundScan() {
        nfcManager.startScan { [weak self] in
            self?.start(from: "nfc")
        }
    }

    // MARK: - 内部

    private func setState(_ newState: SessionState) {
        guard newState != session.state else { return }
        session.state = newState
        NotificationCenter.default.post(name: .sessionStateDidChange, object: session)
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
}

// MARK: - 测试 / 调试辅助

#if DEBUG
extension SessionManager {
    /// 仅供开发：手动复位到 IDLE
    func debugReset() {
        session = BeminderSession()
        NotificationCenter.default.post(name: .sessionStateDidChange, object: session)
    }
}
#endif