//
//  BeminderApp.swift
//  Beminder
//
//  App 入口。NFC 快捷指令通过 beminder:// URL 唤起，App 用 onOpenURL 接住。
//

import SwiftUI
import UserNotifications

@main
struct BeminderApp: App {
    @StateObject private var sessionManager = SessionManager.shared

    init() {
        // M7：App 在前台时 iOS 默认静默投递本地通知，声明 willPresent 才能在
        // 前台也把 warning 弹出来，兑现"前台可见提醒"的注释承诺。
        UNUserNotificationCenter.current().delegate = Self.notificationDelegate
        NotificationHelper.requestAuthorizationIfNeeded()
    }

    /// 通知中心代理，托管在静态实例上避免 deinit 后回调悬空。
    /// 前台同样展示通知并播放提示音（M7）。
    private static let notificationDelegate: UNUserNotificationCenterDelegate = ForegroundNotificationPresenter()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionManager)
                .onOpenURL { url in
                    SessionManager.shared.handleLaunch(url: url)
                }
        }
    }
}

/// 让前台通知可见（M7）。
private final class ForegroundNotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}