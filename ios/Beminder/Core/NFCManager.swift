//
//  NFCManager.swift
//  Beminder
//
//  应用内 NFC 扫描（前台手动触发/开发备用入口）。
//  实际生产路径是 iOS 快捷指令的 NFC 自动化唤起 App（见 story-1.1 dev 文档），
//  CoreNFC 在这里提供一个可控的手动扫描通道。
//
//  层级约定（working.md「Core NFC 不删、不包 #if DEBUG」）：
//  - canImport(CoreNFC) = source compilation guard（编译层兼容，防非 iOS 平台编译炸）
//  - App 是否拥有 NFC capability = project configuration（entitlement / signing）
//  两者不混。真实 NFC 能力由 entitlement / signing / target 配置决定，
//  此文件只负责"有 CoreNFC 时实现可编译"。

import Foundation

#if canImport(CoreNFC)
import CoreNFC

final class NFCManager: NSObject, NFCNDEFReaderSessionDelegate {
    private var onDetected: (() -> Void)?
    private var session: NFCNDEFReaderSession?

    /// 开始一次前台 NFC 扫描，读到 FoloToy 标签即回调。
    /// M8：免费档无权启用 NFC Tag Reading entitlement，readingAvailable 恒为 false，
    /// 这条触发路径当前不可用（README 列为后续能力）。不可用时不再是静默无反馈，
    /// 记录明确日志，避免开发者误以为已成功调起扫描会话。
    func startScan(onDetected: @escaping () -> Void) {
        guard NFCNDEFReaderSession.readingAvailable else {
            NSLog("Beminder NFC: readingAvailable == false（免费档未启用 NFC Tag "
                  + "entitlement），CoreNFC 扫描不可用；见 docs/mvp.md 后续能力")
            return
        }
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

#else
/// 无 CoreNFC 的平台（如未来 macOS target）占位实现。
/// 只保证 SessionManager 对 NFCManager 的引用可编译，不拥有任何 NFC 能力。
final class NFCManager: NSObject {
    func startScan(onDetected: @escaping () -> Void) {}
}
#endif
