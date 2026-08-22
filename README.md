# Beminder

一个 NFC 启动、iPhone 计时、BLE 通知、FoloToy 物理报警的共享单车防遗忘系统。

用户骑车前用 iPhone 碰一下 FoloToy，系统接管记忆。35 分钟后如果订单仍可能在进行，FoloToy 显示警告并发出声音，把用户从现实世界里拉回来检查美团订单。

This repository is designed to be publishable with only fake examples.

## 文档导航

- mvp.md 产品定义
- prd.md 产品需求文档
- rfc.md 架构设计文档（含关键设计决策与 BLE 协议）
- roadmap.md 迭代路线
- stories/ 需求派生，按迭代拆分
- docs/dev/devN/ 迭代文档，按版本标签组织
- working.md 工作日志

## 开发顺序

v0.1 拆成三个迭代：dev1 打通 NFC 触发和 iPhone 计时，dev2 打通 BLE 链路，dev3 完成警告展示、按钮确认和端到端闭环。详细见 roadmap.md。

## Privacy

This repository is designed to be publishable with only fake examples.
