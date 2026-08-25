# Beminder

一个 NFC 启动、iPhone 计时、BLE 通知、FoloToy 物理报警的共享单车防遗忘系统。

用户骑车前用 iPhone 碰一下 FoloToy，系统接管记忆。35 分钟后如果订单仍可能在进行，FoloToy 显示警告并发出声音，把用户从现实世界里拉回来检查美团订单。

This repository is designed to be publishable with only fake examples.

## 文档导航

- docs/mvp.md 产品定义
- docs/prd.md 产品需求文档
- docs/rfc.md 架构设计文档（含关键设计决策与 BLE 协议）
- docs/roadmap.md 迭代路线
- stories/ 需求派生，按迭代拆分
- docs/dev/devN/ 迭代文档，按版本标签组织
- working.md 工作日志（仓库根）

## 开发顺序

v0.1 拆成三个迭代：dev1 打通 NFC 触发和 iPhone 计时，dev2 打通 BLE 链路，dev3 完成警告展示、按钮确认和端到端闭环。详细见 roadmap.md。六个 story（story-1.1 ~ story-3.2）均已实现。

## 构建与运行

主要交付两部分代码：iOS App 与 FoloToy 固件。本仓库提供源码与协议常量，具体构建需接入各自宿主工程。

### iOS（Beminder App）

源码在 `ios/Beminder/`，是独立的 SwiftUI + CoreBluetooth 工程。

- 需要 macOS + Xcode，目标设备 iPhone 13 mini / iOS 17+（需支持 NFC 与 Core Bluetooth）
- `Core/BeminderConstants.swift` 定义 BLE UUID 与状态枚举，`Timeouts.swift` 里 `TimeoutsConfig.currentMode` 决定超时模式（production=35 分钟，development=30 秒测试）
- Info.plist 已声明蓝牙后台模式（bluetooth-central）、NFC 与位置的权限说明、beminder:// URL scheme
- 真机步骤：用 Xcode 打开并签名到你的 iPhone。会话入口：当前真机验证阶段使用应用内**手动开始**作为临时入口；NFC 入口仍保留在产品设计中，待免费开发环境下 iOS 快捷指令 NFC 自动化（`beminder://`）的可行性验证后决定是否启用；App 内 Core NFC 读取作为需额外 entitlement 的后续能力

### FoloToy 固件

源码在 `firmware/main/`，基于 ESP-IDF + NimBLE + LVGL，模块化独立。**源码交付，非已测二进制**（M22）：本仓 `firmware/main` 尚未作为独立工程编译验证，真机验证产物是 ai-passport 宿主工程接入本仓源码后的变体（见 docs/mvp.md 可复现性声明）。

- 需要 ESP-IDF 工具链 + 目标板（ESP32-C3，FoloToy AI Passport）
- 接入 FoloToy 开源工程的方式：把 `firmware/main/` 下的文件并入宿主 main，把 `demos/demo_beminder.h` 的 `demo_beminder` 挂到宿主 demo 注册表；`beminder_audio_init` 的 beep 回调挂钩到宿主实际发声接口；`BEMINDER_KEY_CONFIRM` 按真实按键映射
- UUID 与枚举定义在 `beminder_config.h`，必须与 iOS 端 `BeminderConstants.swift` 保持一致
- 状态机边界：iPhone 是时间唯一权威，FoloToy 不自行计时，只收命令切换屏幕与声音

## Privacy

This repository is designed to be publishable with only fake examples.
