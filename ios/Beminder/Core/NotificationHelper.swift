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

    /// 按绝对时间调度到点提醒（warningTime）。App 后台也能收到（story-1.2 R1.2.5 兜底）。
    static func scheduleWarning(at date: Date?) {
        guard let date else { return }
        let content = UNMutableNotificationContent()
        content.title = "Beminder"
        content.body = SessionState.warning.label
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: "beminder.warning", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    /// 前台到达 WARNING 时立即弹一次可见提醒。
    static func fireWarningIfActive() {
        let content = UNMutableNotificationContent()
        content.title = "Beminder"
        content.body = SessionState.warning.label
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 0.1, repeats: false)
        let request = UNNotificationRequest(identifier: "beminder.warning.now", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}