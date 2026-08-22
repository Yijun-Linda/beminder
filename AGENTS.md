# Beminder 项目局部规则（AGENTS.md）

## 项目结构

- mvp.md 产品定义
- prd.md 产品需求文档
- rfc.md 架构设计文档
- roadmap.md 迭代路线
- stories/ 需求派生，每个 story 一个文件
- docs/dev/devN/ 迭代文档，按版本标签组织
- working.md 工作日志

## 派生链约定

roadmap:v0.1 派生 stories/story-N.M.md，每个 story 对应 docs/dev/devN/N.M-xxx.md 迭代文档。开发顺序严格按 roadmap，不跨迭代。

## 更新要求

- 每次开发或修复后更新 working.md 的 Changelog
- 功能产生 bug 时，在 docs/dev/devN/ 对应迭代文档中记录修复进度
- story 完成后更新其任务完成情况和状态

## 频繁 commit

采用小步提交：scaffold 一次，每个 story 完成后一次，每个 bug 修复一次。不要在提交里混入无关文件。

## 环境约束

- iPhone 13 mini / iOS 17.6.1，NFC + Core Bluetooth
- FoloToy AI Passport，ESP32-C3 + LVGL，通过 USB Type-C 刷固件
- 开发使用 30 秒测试模式，正式 35 分钟

## 兼容约束

- 不要破坏 iPhone 是大脑、FoloToy 是身体的职责边界
- 时间唯一权威是 iPhone，FoloToy 不自己计时
- v0.1 不碰美团内部接口
