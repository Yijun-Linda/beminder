//
//  ContentView.swift
//  Beminder
//
//  极简状态页：显示当前 Guardian 会话状态，提供手动 NFC 扫描入口（开发用）。
//  story-1.1 阶段不涉及 BLE，状态只来自 SessionManager。
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var sessionManager: SessionManager

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text(sessionManager.session.state.label)
                .font(.largeTitle.weight(.bold))
                .multilineTextAlignment(.center)

            if let start = sessionManager.session.startTime {
                Text("开始于 \(start.formatted(date: .omitted, time: .shortened))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if sessionManager.session.foloToyConnected {
                Text("FoloToy 已连接")
                    .font(.caption)
                    .foregroundStyle(.green)
            }

            Spacer()

            Button {
                sessionManager.startForegroundScan()
            } label: {
                Label("扫描 FoloToy", systemImage: "dot.radiowaves.left.and.right")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(sessionManager.isGuarding)
        }
        .padding()
    }
}

#Preview {
    ContentView().environmentObject(SessionManager.shared)
}