# Beminder 迭代路线（Roadmap）

日期：2026-08-22
当前版本：v0.1（MVP，Minimum Viable Product，最小可行产品）

## 路线图总览

Beminder 从 MVP 到完整产品分四个版本。

- v0.1 MVP：NFC 启动 + iPhone 计时 + BLE 通知 + FoloToy 物理报警，验证核心假设
- v0.2：P0 人车分离分级警告，降低误报
- v0.3：NFC 物理确认，替代按钮确认
- v1.0：美团 deep link / universal link，提醒器升级为操作器

本 roadmap 当前聚焦 v0.1。v0.2 及以后只记录方向，不展开。

## v0.1 迭代拆解

v0.1 按 mvp.md 的开发顺序拆成三个迭代（dev），每个迭代派生一组 story。

- dev1，iPhone 大脑基础，目标是把 iPhone 变成可靠的计时大脑。派生 stories/story-1.1.md 和 stories/story-1.2.md，迭代文档在 docs/dev/dev1/
- dev2，BLE 链路打通，目标是让 iPhone 和 FoloToy 通过 BLE 通信。派生 stories/story-2.1.md 和 stories/story-2.2.md，迭代文档在 docs/dev2/
- dev3，完整闭环，目标是把整条链串起来完成端到端验收。派生 stories/story-3.1.md 和 stories/story-3.2.md，迭代文档在 docs/dev3/

派生链约定：roadmap:v0.1 派生 stories/story-N.M.md，每个 story 对应 docs/dev/devN/N.M-xxx.md 迭代文档。功能产生 bug 时，在对应迭代文档中记录修复进度。

### dev1：iPhone 大脑基础

目标：把 iPhone 变成可靠的计时大脑，验证 NFC 触发和绝对时间状态机。

- story-1.1 NFC 触发 Beminder 启动
- story-1.2 时间状态机，ACTIVE 到 WARNING，30 秒测试模式与 35 分钟生产模式

dev1 完成标准：碰一下 FoloToy，iPhone 自动启动 Guardian，30 秒后状态自动进入 WARNING，不需要第二次操作手机。

### dev2：BLE 链路打通

目标：让 iPhone 和 FoloToy 通过 BLE 通信，状态能写到设备上。

- story-2.1 FoloToy BLE 外设（Beminder Service）
- story-2.2 iPhone BLE 主设备连接与状态同步

dev2 完成标准：iPhone 能发现并连接 FoloToy，写入 ACTIVE 和 WARNING，FoloToy 屏幕随之切换。

### dev3：完整 MVP 闭环

目标：把整条链串起来，完成端到端验收。

- story-3.1 FoloToy 警告展示 + 声音
- story-3.2 按钮确认 + 端到端闭环

dev3 完成标准：30 秒端到端闭环跑通，然后切换到 35 分钟，完整 MVP 验收通过。

## v0.1 验收标准（MVP Definition of Done）

NFC 到 ACTIVE 到 WARNING 到 BLE 到 FoloToy 屏幕警告和声音再到按钮确认，14 步闭环中前 11 步由机器完成，后 3 步由人类完成。详细见 prd.md 第 7 节和 mvp.md 第 13 节。

## 后续版本方向（不展开）

### v0.2：P0 人车分离

35 分钟后用 distance(P0, currentLocation) 分级警告。距离小于 30 米给普通提醒，大于 100 米给高强度提醒。GPS 和活动识别在此版本进入。

### v0.3：NFC 物理确认

警告状态下用户碰一下 FoloToy 即确认，替代按钮。需要验证 FoloToy NFC 芯片能否作为读取器，或者保持标签角色由 iPhone 反向触发。

### v1.0：美团自动操作

研究美团是否有可用的 deep link、universal link、App Intent 或快捷指令动作。如果存在稳定入口，把提醒器升级为操作器，用户按一下 FoloToy 按钮直接打开美团关单页面。

## 原则

1. 不跨阶段开发，每个迭代完成再进下一个。
2. 每次迭代结束后更新 working.md 的 Changelog 和 docs/dev/devN/ 下对应文档。
3. 功能产生 bug 时，在对应迭代文档中记录修复进度，不另开会话。
