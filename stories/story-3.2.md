# Story 3.2：按钮确认 + 端到端闭环

- story id：story-3.2
- 所属迭代：dev3
- 派生自：roadmap:v0.1
- 状态：待开发
- 关联迭代文档：docs/dev/dev3/3.2-button-ack-e2e.md

## 目标

用户看到警告后按 FoloToy 按钮确认，系统进入已确认状态，然后完整 30 秒端到端闭环跑通，最后切换到 35 分钟正式模式。

## 需求条目（可测试）

- R3.2.1 按钮 1（处理）按下后，FoloToy 通过 BLE 发送 ACK 给 iPhone
- R3.2.2 iPhone 收到 ACK 后进入 CLOSED / ACKNOWLEDGED 状态
- R3.2.3 30 秒端到端闭环：NFC 到 ACTIVE 到 WARNING 到 BLE 到 FoloToy 红屏和声音到按钮确认
- R3.2.4 闭环跑通后切换到 PRODUCTION_TIMEOUT = 35 分钟
- R3.2.5 按钮 2（稍后）和按钮 3（取消守护）预留，本 story 不实现

## 技术要点

- 按钮只是确认用户已看到提醒，不自动判断美团订单是否真的结束，见 mvp.md 第 9 节
- 这是 v0.1 的最后一块，串起全部前序 story
- 35 分钟只是参数切换，不再涉及架构改动，见 rfc.md ADR-004

## 相关文件路径

- 固件按钮逻辑：firmware/main/demo_beminder.c（待创建）
- iPhone ACK 接收：ios/Beminder/BLEManager.swift（待创建）
- 端到端测试记录：docs/dev/dev3/3.2-button-ack-e2e.md

## 任务完成情况

- [ ] 按钮 1 ACK 回传
- [ ] iPhone 进入 CLOSED
- [ ] 30 秒端到端闭环跑通
- [ ] 切换 35 分钟正式模式

## 验收标准

30 秒完整闭环跑通，随后只改超时参数为 35 分钟，全链路不回归。
