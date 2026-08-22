# Story 1.2：时间状态机（ACTIVE 到 WARNING）

- story id：story-1.2
- 所属迭代：dev1
- 派生自：roadmap:v0.1
- 状态：待开发
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

- 状态模型：ios/Beminder/Models.swift（待创建）
- 状态机与超时：ios/Beminder/SessionManager.swift（待创建）
- 超时参数：.env.example 中 DEVELOPMENT_TIMEOUT_SECONDS / PRODUCTION_TIMEOUT_MINUTES

## 任务完成情况

- [ ] 绝对时间模型实现
- [ ] 30 秒测试模式跑通
- [ ] 35 分钟生产模式参数化
- [ ] 挂起 / 重启后重算正确
- [ ] ACTIVE 到 WARNING 自动切换

## 验收标准

不需要再次操作手机，系统能够从 ACTIVE 自动进入 WARNING。
