//
//  BeminderApp.swift
//  Beminder
//
//  App 入口。NFC 快捷指令通过 beminder:// URL 唤起，App 用 onOpenURL 接住。
//

import SwiftUI

@main
struct BeminderApp: App {
    @StateObject private var sessionManager = SessionManager.shared

    init() {
        NotificationHelper.requestAuthorizationIfNeeded()
    }

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