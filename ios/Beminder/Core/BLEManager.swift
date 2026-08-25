//
//  BLEManager.swift
//  Beminder
//
//  iPhone 作为 BLE（Bluetooth Low Energy，低功耗蓝牙）主设备（Central），
//  扫描、发现并连接 FoloToy（Peripheral），把 Session 状态写入设备。
//
//  对应 story-2.2：R2.2.1 扫描发现，R2.2.2 建链，R2.2.3/2.2.4 状态写入，
//  R2.2.5 断线处理，R2.2.6 后台模式（在 Info.plist 声明）。
//
//  设计约束：iPhone 是时间唯一权威，这里只负责把 iPhone 算出的状态下发，
//  不做任何时间判断；收到 FoloToy 的 ACK 状态（CLOSED）时回调给 SessionManager。
//

import Foundation
import CoreBluetooth
import Combine

final class BLEManager: NSObject, ObservableObject, CBCentralManagerDelegate,
                        CBPeripheralDelegate {

    static let shared = BLEManager()

    /// 是否已连接上 FoloToy。驱动内容视图的连接状态显示。
    @Published private(set) var isConnected = false {
        didSet {
            guard oldValue != isConnected else { return }
            NotificationCenter.default.post(name: .foloToyConnectionDidChange, object: isConnected)
        }
    }

    private var central: CBCentralManager!

    // L4：peripheral / commandCharacteristic / stateCharacteristic 会被 CBCentralManager
    // 的代理回调（自建后台队列 com.beminder.ble）与主线程（send/disconnect）跨队列读写，
    // 裸属性访问构成 Thread Sanitizer 会报的真实数据竞争。所有对它们的读写都经
    // bleQueue 串行化，对外只暴露线程安全的 send()。
    private let bleQueue = DispatchQueue(label: "com.beminder.ble")
    private var _peripheral: CBPeripheral?
    private var _commandCharacteristic: CBCharacteristic?
    private var _stateCharacteristic: CBCharacteristic?

    /// 遇到 Beminder Service 特征时采用的扫描选项
    private let scanOptions: [String: Any] = [CBCentralManagerScanOptionAllowDuplicatesKey: false]

    /// 已发现但未连接的候选设备（仅用于日志 / 调试）
    private var discoveredPeripherals: Set<CBPeripheral> = []

    private override init() {
        super.init()
        // 启用状态保存与恢复，App 被系统挂起/杀回时能恢复连接（配合 Info.plist
        // 的 bluetooth-central 后台模式，见 rfc ADR-003 与 story-2.2）。
        // 关键：把 central 的回调队列设为与底层属性访问共用的 bleQueue，
        // 让所有代理回调与 send()/disconnect() 天然落在同一串行队列上（L4）。
        central = CBCentralManager(delegate: self,
                                   queue: bleQueue,
                                   options: [CBCentralManagerOptionRestoreIdentifierKey:
                                      "com.beminder.central"])
    }

    // MARK: - 对外接口

    /// 开始扫描（自动重连）。
    func startScanning() {
        guard central.state == .poweredOn else {
            setConnected(false)
            return
        }
        central.scanForPeripherals(withServices: [BeminderBLE.serviceUUID],
                                   options: scanOptions)
    }

    /// 停止扫描（如 App 进入前台后不需要再扫）。
    func stopScanning() {
        central.stopScan()
    }

    /// 把当前 Session 状态写进 COMMAND 驱动 FoloToy。线程安全：经 bleQueue 串行化。
    func send(state: SessionState) {
        bleQueue.async { [weak self] in
            guard let self = self else { return }
            guard let peripheral = self._peripheral,
                  let commandCharacteristic = self._commandCharacteristic else { return }
            guard peripheral.state == .connected else { return }

            let cmd = self.command(for: state)
            var value = cmd.rawValue
            let data = Data(bytes: &value, count: 1)
            peripheral.writeValue(data,
                                  for: commandCharacteristic,
                                  type: .withResponse)
        }
    }

    /// 断开连接（如 debug 复位时）。线程安全：经 bleQueue 串行化。
    func disconnect() {
        bleQueue.async { [weak self] in
            guard let self = self else { return }
            guard let peripheral = self._peripheral else { return }
            self.central.cancelPeripheralConnection(peripheral)
        }
    }

    /// 在主线程序列化 isConnected 的写入，避免跨队列修改 @Published 属性
    /// （CBCentralManager 代理回调运行在自建后台队列 com.beminder.ble 上）。
    private func setConnected(_ value: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isConnected = value
        }
    }

    // MARK: - CBCentralManagerDelegate

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            startScanning()
        default:
            setConnected(false)
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        // 已连接则不再重复连（代理回调在 bleQueue 上，直接读 _peripheral）
        guard _peripheral == nil else { return }

        // 广播名优先，如果没有再回落到发现的服务过滤（已按 service 扫描）。
        // M4：名字可能来自缓存（空字符串，常见）或含首尾空白，先 trim；
        // 若 trim 后为空则视同无名字，与"两个来源都为 nil"一致地依赖
        // serviceUUID 扫描兜底放行，避免误拒正确设备。
        let name = (advertisementData[CBAdvertisementDataLocalNameKey] as? String
            ?? peripheral.name)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // trim 后仍有名字但匹配不上 Beminder 的，记录日志而非静默跳过，
        // 便于排查 "service 匹配成功但广播名异常" 的误连场景（M4）。
        if let trimmed = name, !trimmed.isEmpty,
           trimmed != BeminderBLE.advertisementName {
            NSLog("BLE skipped device, non-Beminder name '%@'", trimmed)
            return
        }

        discoveredPeripherals.insert(peripheral)
        _peripheral = peripheral
        peripheral.delegate = self
        central.stopScan()
        central.connect(peripheral, options: nil)
    }

    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        setConnected(true)
        peripheral.discoverServices([BeminderBLE.serviceUUID])
    }

    /// App 被系统从后台恢复 BLE 状态时回调，恢复已连接的外设。
    func centralManager(_ central: CBCentralManager,
                        willRestoreState dict: [String: Any]) {
        guard let restored = dict[CBCentralManagerRestoredStatePeripheralsKey]
                as? [CBPeripheral], let restoredPeripheral = restored.first else {
            return
        }
        _peripheral = restoredPeripheral
        _commandCharacteristic = nil
        _stateCharacteristic = nil
        restoredPeripheral.delegate = self
        // H1：恢复连接后连接实际仍存活，但 commandCharacteristic 已被清空。
        // 必须重新 discoverServices，否则 send() 在 commandCharacteristic == nil 时
        // 静默返回，后台报警主链路（WARNING 写入）会永远发不到设备。
        restoredPeripheral.discoverServices([BeminderBLE.serviceUUID])
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        setConnected(false)
        _peripheral = nil
        startScanning()   // 重试
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        setConnected(false)
        _peripheral = nil
        _commandCharacteristic = nil
        _stateCharacteristic = nil
        startScanning()   // 自动重连
    }

    // MARK: - CBPeripheralDelegate

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {
        guard error == nil, let services = peripheral.services else { return }
        for service in services where service.uuid == BeminderBLE.serviceUUID {
            peripheral.discoverCharacteristics([BeminderBLE.commandUUID,
                                                BeminderBLE.stateUUID],
                                               for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard error == nil, let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            switch characteristic.uuid {
            case BeminderBLE.commandUUID:
                _commandCharacteristic = characteristic
            case BeminderBLE.stateUUID:
                _stateCharacteristic = characteristic
                // 订阅 Notify，接收 FoloToy 的 ACK（如按钮确认 CLOSED）
                peripheral.setNotifyValue(true, for: characteristic)
            default:
                break
            }
        }
        // 订阅完成后，把当前状态同步一次，确保设备与 App 对齐
        if _commandCharacteristic != nil {
            send(state: SessionManager.shared.session.state)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard characteristic == _stateCharacteristic,
              let value = characteristic.value,
              value.count == 1 else { return }
        let rawState = value[0]
        guard let state = SessionState(rawValue: rawState) else { return }

        // 把 FoloToy 侧的 ACK 状态（CLOSED）同步回大脑的 SessionManager
        NotificationCenter.default.post(name: .foloToyStateDidChange, object: state)
    }

    // MARK: - 工具

    /// Session 状态 → BLE COMMAND。CLOSED 由 FoloToy 反向通知，不主动写。
    private func command(for state: SessionState) -> BLECommand {
        switch state {
        case .active:  return .start
        case .warning: return .warning
        default:       return .reset
        }
    }
}