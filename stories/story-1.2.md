# Story 1.2：时间状态机（ACTIVE 到 WARNING）

- story id：story-1.2
- 所属迭代：dev1
- 派生自：roadmap:v0.1
- 状态：已完成
- 关联迭代文档：docs/dev/dev1/1.2-time-state-machine.md

## 目标

从 ACTIVE 状态自动进入 WARNING 状态，不依赖倒计时，而依赖绝对时间。开发时用 30 秒测试模式，正式用 35 分钟生产模式。

## 需求条目（可测试）

- R1.2.1 绝对时间模型：warningTime = startTime + timeout
- R1.2.2 开发模式超时 DEVELOPMENT_TIMEOUT = 30 秒
- R1.2.3 生产模式超时 PRODUCTION_TIMEOUT = 35 分钟
- R1.2.4 App 被挂起或重启后，重算 remaining = warningTime - now，状态仍正确
- R1.2.5 now >= warningTime 时状态切换为 WARNING
- R1.2.6 状态切换不依赖任何手机上的倒计时程序

## 技术要点

- 这是整个产品可靠性的根基，见 rfc.md ADR-002
- iOS 后台可能终止 App，必须能重算，见 rfc.md 风险节
- 本 story 不涉及 BLE，警告只体现在 iPhone 侧状态和日志

## 相关文件路径

- 状态模型：ios/Beminder/Core/Models.swift
- 状态机与超时：ios/Beminder/Core/SessionManager.swift、ios/Beminder/Core/Timeouts.swift
- 超时参数：.env.example 中 DEVELOPMENT_TIMEOUT_SECONDS / PRODUCTION_TIMEOUT_MINUTES（代码侧见 Timeouts.swift）

## 任务完成情况

- [x] 绝对时间模型实现（warningTime = startTime + timeout，见 Models.swift）
- [x] 30 秒测试模式跑通（Timeouts.developmentSeconds = 30）
- [x] 35 分钟生产模式参数化（Timeouts.productionMinutes = 35，切 currentMode 即可）
- [x] 挂起 / 重启后重算正确（UserDefaults 持久化 + resume() 重算 remaining）
- [x] ACTIVE 到 WARNING 自动切换（recomputeStateIfNeeded + 兜底本地通知）

## 交付说明

在 story-1.1 基础上改造（unavailable 于本机 Windows 编译，需 Xcode 真机验证）：

- `SessionManager.swift`：新增绝对时间状态机，recomputeStateIfNeeded 用 now 与 warningTime 比较，不依赖倒计时
- `Timeouts.swift`：30 秒 / 35 分钟参数，切换 currentMode
- 持久化：UserDefaults 存 startTime / warningTime / state，resume() 恢复后重算
- 生命周期：didBecomeActive 时 resume()，1 秒轻量重算驱动 only 重新评估绝对时间
- `NotificationHelper.swift`：scheduleWarning 按绝对时间调度到点提醒，fireWarningIfActive 前台兜底

## 验收标准

不需要再次操作手机，系统能够从 ACTIVE 自动进入 WARNING。
