# Story 1.1：NFC 触发 Beminder 启动

- story id：story-1.1
- 所属迭代：dev1
- 派生自：roadmap:v0.1
- 状态：待开发
- 关联迭代文档：docs/dev/dev1/1.1-nfc-trigger.md

## 目标

用户用 iPhone 碰一下 FoloToy，iPhone 自动识别 NFC（Near Field Communication，近场通信）标签，记录启动时间和位置，进入 ACTIVE 状态。这是整个系统的启动仪式。

## 需求条目（可测试）

- R1.1.1 iPhone 能识别 FoloToy 的 NFC 标签
- R1.1.2 NFC 触发后自动运行自动化，不需要询问（关闭 Ask Before Running）
- R1.1.3 记录 startTime = 当前时间
- R1.1.4 记录 P0 = 当前定位
- R1.1.5 Session 状态进入 ACTIVE
- R1.1.6 显示通知：Beminder 已启动

## 技术要点

- iOS 快捷指令（Shortcut）NFC 自动化作为入口，唤起 Beminder App
- App 负责真正的事件记录，Shortcut 只做入口不做大脑，见 rfc.md ADR-003
- 本 story 不涉及 BLE（Bluetooth Low Energy，低功耗蓝牙）

## 相关文件路径

- iOS Shortcut 配置：NFC 自动化，用户手动配置，步骤记录在 docs/dev/dev1/1.1-nfc-trigger.md
- Beminder App 入口：ios/Beminder/AppDelegate.swift（待创建）
- Session 创建：ios/Beminder/SessionManager.swift（待创建）

## 任务完成情况

- [ ] iPhone 识别 FoloToy NFC
- [ ] 自动化自动触发，无需询问
- [ ] 记录 startTime / P0
- [ ] 状态进入 ACTIVE
- [ ] 通知：Beminder 已启动

## 验收标准

碰一下 FoloToy，iPhone 自动显示 Beminder 已启动，无需第二次操作手机。
