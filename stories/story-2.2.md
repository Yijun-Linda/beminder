# Story 2.2：iPhone BLE 主设备连接与状态同步

- story id：story-2.2
- 所属迭代：dev2
- 派生自：roadmap:v0.1
- 状态：待开发
- 关联迭代文档：docs/dev/dev2/2.2-iphone-ble-central.md

## 目标

iPhone App 作为 BLE（Bluetooth Low Energy，低功耗蓝牙）主设备（Central），扫描、发现并连接 FoloToy，把 Session 状态写入设备。

## 需求条目（可测试）

- R2.2.1 扫描并发现 Beminder Service
- R2.2.2 建立与 FoloToy 的连接
- R2.2.3 进入 ACTIVE 时向 FoloToy 写入 ACTIVE
- R2.2.4 进入 WARNING 时向 FoloToy 写入 WARNING
- R2.2.5 连接断开时更新 foloToy 连接状态
- R2.2.6 声明 bluetooth-central 后台模式

## 技术要点

- BLE 通信必须由原生 App 承担，Shortcut 不能作为持续运行的 BLE 程序，见 rfc.md ADR-003
- 后台行为受系统调度限制，配合状态保存与恢复（state preservation / restoration）
- 连接状态是数据模型的一部分，见 rfc.md 第 5 节

## 相关文件路径

- BLE 管理器：ios/Beminder/BLEManager.swift（待创建）
- 状态同步入口：ios/Beminder/SessionManager.swift（待创建）
- 工程配置：ios/Beminder/Info.plist（声明后台模式，待创建）

## 任务完成情况

- [ ] 扫描发现 Beminder Service
- [ ] 连接与断线处理
- [ ] ACTIVE / WARNING 写入
- [ ] 后台模式声明

## 验收标准

iPhone 自动连接 FoloToy，状态切换时设备屏幕同步变化，断线不崩溃且能重连。
