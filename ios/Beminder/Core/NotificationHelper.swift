//
//  NotificationHelper.swift
//  Beminder
//
//  本地通知封装。用于"Beminder 已启动"这类即时的可见反馈。
//

import Foundation
import UserNotifications

enum NotificationHelper {
    /// 首次调用时请求通知权限。
    static func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// 立即弹一条"Beminder 已启动"通知。
    static func fireStarted(source: String) {
        let content = UNMutableNotificationContent()
        content.title = "Beminder"
        content.body = source == "nfc" ? "已识别 FoloToy，开始骑行守护" : "开始骑行守护"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: "beminder.started", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}