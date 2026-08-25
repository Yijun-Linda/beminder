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

    private var peripheral: CBPeripheral?
    private var commandCharacteristic: CBCharacteristic?
    private var stateCharacteristic: CBCharacteristic?

    /// 遇到 Beminder Service 特征时采用的扫描选项
    private let scanOptions: [String: Any] = [CBCentralManagerScanOptionAllowDuplicatesKey: false]

    /// 已发现但未连接的候选设备（仅用于日志 / 调试）
    private var discoveredPeripherals: Set<CBPeripheral> = []

    private override init() {
        super.init()
        // 启用状态保存与恢复，App 被系统挂起/杀回时能恢复连接（配合 Info.plist
        // 的 bluetooth-central 后台模式，见 rfc ADR-003 与 story-2.2）。
        central = CBCentralManager(delegate: self,
                                   queue: DispatchQueue(label: "com.beminder.ble"),
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

    /// 把当前 Session 状态写进 COMMAND 驱动 FoloToy。
    func send(state: SessionState) {
        guard let peripheral = peripheral,
              let commandCharacteristic = commandCharacteristic else { return }
        guard peripheral.state == .connected else { return }

        let cmd = command(for: state)
        var value = cmd.rawValue
        let data = Data(bytes: &value, count: 1)
        peripheral.writeValue(data,
                              for: commandCharacteristic,
                              type: .withResponse)
    }

    /// 断开连接（如 debug 复位时）。
    func disconnect() {
        guard let peripheral = peripheral else { return }
        central.cancelPeripheralConnection(peripheral)
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
        // 已连接则不再重复连
        guard self.peripheral == nil else { return }

        // 广播名优先，如果没有再回落到发现的服务过滤（已按 service 扫描）
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String
            ?? peripheral.name
        // 名字存在但匹配不上 Beminder 的，直接跳过（收紧过滤，见 code_review 审计）；
        // 名字为 nil（iOS 尚未解析广播名）时依赖上面的 serviceUUID 扫描兜底。
        if let name, name != BeminderBLE.advertisementName { return }

        discoveredPeripherals.insert(peripheral)
        self.peripheral = peripheral
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
        self.peripheral = restoredPeripheral
        commandCharacteristic = nil
        stateCharacteristic = nil
        restoredPeripheral.delegate = self
    }

    func centralManager(_ central: CBCentralManager,
                        didFailToConnect peripheral: CBPeripheral,
                        error: Error?) {
        setConnected(false)
        self.peripheral = nil
        startScanning()   // 重试
    }

    func centralManager(_ central: CBCentralManager,
                        didDisconnectPeripheral peripheral: CBPeripheral,
                        error: Error?) {
        setConnected(false)
        self.peripheral = nil
        commandCharacteristic = nil
        stateCharacteristic = nil
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
                commandCharacteristic = characteristic
            case BeminderBLE.stateUUID:
                stateCharacteristic = characteristic
                // 订阅 Notify，接收 FoloToy 的 ACK（如按钮确认 CLOSED）
                peripheral.setNotifyValue(true, for: characteristic)
            default:
                break
            }
        }
        // 订阅完成后，把当前状态同步一次，确保设备与 App 对齐
        if commandCharacteristic != nil {
            send(state: SessionManager.shared.session.state)
        }
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard characteristic == stateCharacteristic,
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