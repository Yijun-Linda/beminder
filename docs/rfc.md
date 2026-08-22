# Beminder 架构设计文档（RFC，Request for Comments）

版本：v1.0（对应 mvp.md v0.1）
日期：2026-08-22
状态：draft

## 1. 背景

RFC 记录 Beminder 的架构、边界、关键设计决策和演进策略。本文档面向后续接手开发的 AI 和人类工程师，目标是让任何人在不读 brainstorm 的前提下，能独立理解系统为什么这么设计。

## 2. 架构概述

系统只有一个核心原则：iPhone 是大脑（Brain），FoloToy 是身体（Body）。

iPhone 负责所有判断，包括记录开始时间、记录位置、持有状态、决定是否进入警告。FoloToy 负责所有物理交互，包括 NFC（Near Field Communication，近场通信）标签、屏幕显示、声音、实体按钮、BLE（Bluetooth Low Energy，低功耗蓝牙）外设角色。它不计算时间，不知道美团发生了什么，只响应 iPhone 给它的状态。

```text
┌──────────────────┐
│     FoloToy      │    NFC 标签 + BLE 外设
│       NFC        │
└────────┬─────────┘
         │ NFC
         ▼
┌──────────────────┐
│      iPhone      │    NFC 读取 + iOS App + BLE 主设备
│  startTime / P0  │
│  state / +35min  │
└────────┬─────────┘
         │ BLE
         ▼
┌──────────────────┐
│     FoloToy      │    警告显示 + 声音 + 按钮
└────────┬─────────┘
         ▼
    用户处理订单
         ▼
       美团
```

## 3. 系统组件

### 3.1 FoloToy（AI Passport 硬件）

ESP32-C3 + LVGL 屏幕 + NFC + 蓝牙 + 扬声器 + 三个实体按钮，可刷自定义固件。在系统里承担三个角色。

一是 NFC 标签，被 iPhone 识别，作为 Guardian 启动的物理触发器。二是 BLE 外设，广播 Beminder Service，接收 iPhone 的状态写入。三是状态显示器，根据收到的状态展示对应页面并播放声音。

### 3.2 iPhone（13 mini / iOS 17.6.1）

承担四个职责。一是 NFC 读取，识别 FoloToy 标签并触发自动化。二是入口，iOS 快捷指令（Shortcut）作为 NFC 触发的入口，但只负责唤起 App。三是大脑，Beminder App 持有 Session 状态、绝对时间、位置记录。四是 BLE 主设备（Central），发现、连接 FoloToy，写入状态。

### 3.3 美团 App

外部系统，v0.1 完全不接入。用户手动打开美团结束订单，是闭环里唯一的人类动作。

## 4. 状态机

```text
IDLE
  │ NFC detected
  ▼
ACTIVE
  │ now >= warningTime
  ▼
WARNING
```

三个状态之外预留一个 CLOSED（确认后进入），v0.1 只实现 IDLE / ACTIVE / WARNING。

## 5. 数据模型

```text
BeminderSession
  state:          IDLE / ACTIVE / WARNING（预留 CLOSED）
  startTime:      Date
  warningTime:    Date（= startTime + timeout）
  startLocation:  CLLocation（P0，只记录不参与判断）
  foloToy:        connected / disconnected
```

## 6. 关键设计决策（ADR，Architecture Decision Record）

### ADR-001 iPhone 是时间唯一权威
FoloToy 不自己计时、不显示秒数倒计时，只显示状态，避免出现两个时钟互相矛盾的来源。

### ADR-002 绝对时间而非倒计时
保存 warningTime = startTime + 35 分钟，而不是启动一个 35 分钟倒计时。iOS 后台 App 可能被系统挂起或终止，绝对时间允许 App 重新唤醒后重算 remaining = warningTime - now。这是整个产品可靠性的根基。

### ADR-003 Shortcut 只做入口，不做大脑
NFC 触发快捷指令，但 BLE 通信必须由原生 App 承担。Apple 的 Core Bluetooth 要求后台能力通过 App 声明（bluetooth-central 后台模式），普通快捷指令不能作为持续运行的 BLE 程序。即使 App 支持后台模式，仍可能被系统终止，因此配合状态保存与恢复（state preservation / restoration）。

### ADR-004 30 秒测试模式
开发阶段超时设为 30 秒，正式模式 35 分钟，其他逻辑不变。硬件项目如果每次调试都等 35 分钟，迭代效率会低到无法工作。30 秒闭环跑通后，35 分钟只是参数，不再是架构问题。

### ADR-005 v0.1 不自动关美团
第一版不做任何美团内部接口调用和逆向。共享单车可能被继续使用，用户也可能只是骑得久，系统不应该擅自替用户结束一个真实交易。物理设备强迫用户确认一次，比自动关订单更安全也更合理。

### ADR-006 P0 只记录，不参与判断
启动时记录当前定位，但 v0.1 完全不用它做判断。记录成本几乎为零，却为 v0.2 的人车分离判断留下数据接口。

## 7. BLE 协议

FoloToy 作为外设（Peripheral），iPhone 作为主设备（Central）。定义 Beminder Service。

- STATE（只读特征值）：0x00 IDLE，0x01 ACTIVE，0x02 WARNING，0x03 CLOSED
- COMMAND（可写特征值）：START，WARNING，RESET

v0.1 实际只需要 ACTIVE 和 WARNING 两个命令。

## 8. 边界与明确不做

v0.1 不做 GPS 人车分离、活动识别（Activity Recognition）、美团骑行状态读取、自动打开美团、自动关闭订单、AI、云端、服务器、账号。这些全部留给 v0.2 及以后。

## 9. 风险与对策

- iOS 后台终止风险：App 被挂起或杀死时，绝对时间模型保证重新唤醒后能正确进入 WARNING。需要针对 iOS 17.6.1 的实际调度行为做真机测试，不靠理论。
- FoloToy NFC 能力不确定：NFC 可能只能作为标签被 iPhone 识别，不一定能作为数据通道。v0.1 按最小依赖设计，NFC 只负责触发，不传输数据。
- 美团关闭入口不确定：美团可能没有可用的 deep link（深度链接）或 universal link（通用链接），v0.1 不依赖它，用户手动打开。
- 误报：单纯 35 分钟固定提醒存在误报（用户还在骑），v0.1 接受这个代价，v0.2 用 P0 距离判断降低。

## 10. 演进策略

v0.1（本版本）是 NFC 触发 + iPhone 计时 + BLE 通知 + FoloToy 报警。v0.2 是 BLE 状态终端增强 + P0 人车分离分级警告。v0.3 是 NFC 物理确认，碰一下即确认。v1.0 研究美团 deep link、universal link、App Intent，把提醒器升级为操作器。

每一级的升级都不推翻 v0.1 的架构，只增加角色和判断逻辑。
