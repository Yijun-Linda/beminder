//
//  NFCManager.swift
//  Beminder
//
//  应用内 NFC 扫描（前台手动触发/开发备用入口）。
//  实际生产路径是 iOS 快捷指令的 NFC 自动化唤起 App（见 story-1.1 dev 文档），
//  CoreNFC 在这里提供一个可控的手动扫描通道。
//

import Foundation
import CoreNFC

final class NFCManager: NSObject, NFCNDEFReaderSessionDelegate {
    private var onDetected: (() -> Void)?
    private var session: NFCNDEFReaderSession?

    /// 开始一次前台 NFC 扫描，读到 FoloToy 标签即回调。
    func startScan(onDetected: @escaping () -> Void) {
        guard NFCNDEFReaderSession.readingAvailable else { return }
        self.onDetected = onDetected

        let s = NFCNDEFReaderSession(delegate: self, queue: .main, invalidateAfterFirstRead: true)
        s.alertMessage = "把 iPhone 顶部靠近 FoloToy"
        s.begin()
        self.session = s
    }

    // MARK: - NFCNDEFReaderSessionDelegate

    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        // v0.1 NFC 只负责触发，不解析标签内容（mvp 第 7 节）
        let handler = self.onDetected
        self.onDetected = nil
        DispatchQueue.main.async { handler?() }
    }

    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        // 扫描结束（成功或取消）都静默复位
        self.onDetected = nil
        self.session = nil
    }
}