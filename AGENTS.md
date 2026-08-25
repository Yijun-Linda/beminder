# Beminder 项目局部规则（AGENTS.md）

## 继承声明

本项目继承全局认知层 `rules/` 目录下的所有约束和原则，包括：
- `../../../rules/SOUL.md` - 核心身份与行为准则
- `../../../rules/USER.md` - 用户画像与沟通风格
- `../../../rules/COMMUNICATION.md` - 沟通规范
- `../../../rules/principles/INDEX.md` - 决策公理

## 项目结构

- docs/mvp.md 产品定义
- docs/prd.md 产品需求文档
- docs/rfc.md 架构设计文档
- docs/roadmap.md 迭代路线
- stories/ 需求派生，每个 story 一个文件
- docs/dev/devN/ 迭代文档，按版本标签组织
- working.md 工作日志（仓库根）

## 工作规范

1. 更新要求
    - 功能产生 bug 时，在 docs/dev/devN/ 对应迭代文档中记录修复进度
    - story 完成后更新其任务完成情况和状态
    - **working.md 更新要求**：每次修改项目后，在仓库根 `working.md` 的 Changelog 区记录改动。一个 bullet 只写一件事。 
2. 派生链约定
    - roadmap:v0.1 派生 stories/story-N.M.md，每个 story 对应 docs/dev/devN/N.M-xxx.md 迭代文档。开发顺序严格按 roadmap，不跨迭代。     
3. **频繁 commit**：功能性的阶段性变化就应该提交，不要攒一大堆才 commit。提交信息用中文，清晰说清楚改了什么。采用小步提交：每个 story 完成后一次，每个 bug 修复一次。不要在提交里混入无关文件。
4. **环境约束**：本项目已进入开发阶段（iOS App + ESP32 固件），需 macOS/Xcode 与 ESP-IDF 工具链，见下方「环境约束」小节。声明必须与真实环境一致，不要写成"纯文档无需运行时"而自相矛盾。
5. **兼容约束**：分析结论可以修改，原始讨论记录（存在工作区 contexts 存量，非本仓）只追加不覆盖。本仓无 docs/raw 目录，若需要保留原始素材请先明确落位再引用，避免指向不存在路径。
6. **Public repo 声明**：本项目最终会发布到公开 GitHub，所有文档使用 fake handles / 占位符。

## 环境约束

- iPhone 13 mini / iOS 17.6.1，NFC + Core Bluetooth
- FoloToy AI Passport，ESP32-C3 + LVGL，通过 USB Type-C 刷固件
- 开发使用 30 秒测试模式，正式 35 分钟

## 兼容约束

- 不要破坏 iPhone 是大脑、FoloToy 是身体的职责边界
- 时间唯一权威是 iPhone，FoloToy 不自己计时
- v0.1 不碰美团内部接口
