//
//  ContentView.swift
//  Beminder
//
//  极简状态页：显示当前 Guardian 会话状态，提供手动"开始守护"入口。
//  Phase 0b 起主入口为手动开始（免费档 NFC 能力受限，见 mvp.md），
//  NFC 扫描降级为预留能力，不在此处默认暴露。
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

            if sessionManager.isGuarding {
                Text("剩余 \(Int(sessionManager.session.remainingSeconds)) 秒")
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
                sessionManager.start(from: .manual)
            } label: {
                Label("开始守护", systemImage: "shield.lefthalf.filled")
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(sessionManager.isGuarding)

            #if DEBUG
            Button("复位（开发）") {
                sessionManager.debugReset()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            #endif
        }
        .padding()
    }
}

#Preview {
    ContentView().environmentObject(SessionManager.shared)
}