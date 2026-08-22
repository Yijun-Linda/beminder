# working.md

## Changelog

### 2026-08-22

- 创建 prd.md 产品需求文档，基于 brainstorm 和 mvp.md 整理
- 创建 rfc.md 架构设计文档，记录 6 个关键设计决策（ADR）与 BLE 协议
- 创建 roadmap.md 迭代路线，把 v0.1 拆成 dev1 / dev2 / dev3 三个迭代
- 创建 stories/ 六个 story 文件（story-1.1 到 story-3.2）
- 创建 docs/dev/ 下 dev1、dev2、dev3 六个迭代文档，含 Bug 追踪区
- 创建 AGENTS.md、README.md、.gitignore、.env.example
- 确认 repo 属性为 public，README 已声明 publishable
- 将 brainstorm_beminder_20260822.md 加入 .gitignore，其内含私有 ChatGPT 会话 URL
- 确认 docs 迭代文档采用 docs/dev/devN/ 嵌套结构，同步修正 stories、roadmap、prd、AGENTS.md、README 中的引用
- 将 beminder 文档按功能分类分 6 次提交进 <PRIVATE-WS> 大仓库（beminder 先放进 <PRIVATE-WS> 大仓库提交，将来真要公开发布时，用 git subtree push --prefix=vibe-muse/beminder （这是工作区已有的发布模式）或 git filter-repo 把 beminder 的历史单独抽出来即可，现在不损失任何东西。）
- commit docs(beminder)：把产品文档移动进 docs/ 目录
- commit chore(beminder)：scaffold ios/ 与 firmware/，先立两端共享 BLE 协议常量（BeminderConstants.swift 与 beminder_config.h，UUID/枚举完全一致）
- 完成 dev1 story-1.1：iPhone 大脑基座。交付 SessionManager/Models/LocationManager/NFCManager/NotificationHelper/Timeouts/Info.plist，双入口（Shortcut NFC 自动化 + 应用内 CoreNFC）。iPhone=大脑边界保持。（无法在 Windows 编译 iOS，验证需在 Mac/Xcode 真机）
- 完成 dev1 story-1.2：绝对时间状态机。warningTime=startTime+timeout，30s/35min 参数化；UserDefaults 持久化 + resume() 重算；到点本地通知兜底
- 完成 dev2 story-2.1：FoloToy BLE 外设固件。gatt service（SERVICE/STATE/COMMAND），STATE 可读+Notify、COMMAND 可写；beminder_ble.c 收命令并按状态回调切换 UI；LVGL 四态屏幕 beminder_screens.c；demo_beminder.c 按 FoloToy demo 注册机制接入。UUID 枚举与 beminder_config.h 两端一致。修复 beminder_ble_init 声明（int）与定义（void）不一致为 void。无法在 Windows 编译 ESP-IDF，真机编译验证留在接入 FoloToy 工程时进行
- 完成 dev2 story-2.2：iPhone BLE Central。BLEManager.swift 扫描 Beminder Service、建链、订阅 STATE Notify、写 COMMAND（START/WARNING）；断线自动重连 + 状态保存恢复。SessionManager.setState 进入 ACTIVE/WARNING 时下发 BLE，连接状态同步到 session.foloToyConnected，新增反向通道 .foloToyStateDidChange 预留按钮 ACK。Info.plist 已含 bluetooth-central 后台模式。验证留 Mac/Xcode 真机
- 完成 dev3 story-3.1：FoloToy 警告展示+声音。beminder_audio.c/.h 用 FreeRTOS 定时器驱动循环告警（2s 间隔、auto-reload 不自动静音）；demo_beminder.c 进入 WARNING 出声、离开停止；WARNING 屏幕红底白字。beep 回调留宿主挂钩。验证需接入 FoloToy 工程真机
- 完成 dev3 story-3.2：按钮 ACK + 端到端闭环 + 切换 35 分钟。固件在 WARNING 下按确认键置 CLOSED 并 Notify；iOS 观察 .foloToyStateDidChange 收 ACK 停 timer + persist；TimeoutsConfig 切 .production（35min）。至此六个 story 全部完成，端到端链路串起（NFC→ACTIVE→WARNING→BLE→红屏声音→按钮 ACK→CLOSED）。真机闭环验证留接入 FoloToy 工程 + Mac/Xcode
- v0.1 MVP 六个 story 全部完成。收尾待办确认。真机验证（iOS 需要在 Mac/Xcode，固件需接入 FoloToy 工程）是后续接入工作
- 收尾：README 补构建与运行指引（iOS 真机步骤 + FoloToy 固件接入方式），全链路无架构改动
- 新增 ios/BeminderCore 纯逻辑 Swift Package，用 Windows 上的 Swift 工具链跑 swift test 验证状态机，脱离对 Xcode / Apple 框架的依赖。抽取的原语：SessionState（IDLE/ACTIVE/WARNING/CLOSED）、GuardianMode + TimeoutsConfig（30s / 35min）、Session（绝对时间 + remainingSeconds）、GuardianMachine（start / recompute / ack / reset，注入 now 保证确定性）。写 11 个测试全部通过（超时参数 2 个 + 状态机 9 个），覆盖：start 仅非守护时生效、recompute 绝对时间到点进 WARNING、重复触发防护、ACK 置 CLOSED、remainingSeconds 钳制非负、development 端到端闭环。两个运行要点：TimeoutsConfig.currentMode 在 Swift 6 严格并发下声明为 nonisolated(unsafe)；运行需设置 SDKROOT 指向 Platforms/6.3.3/Windows.platform/.../Windows.sdk 并把 Runtimes/6.3.3/usr/bin 加入 PATH（运行时 DLL 所在），clang 模块缓存用 CLANG_MODULE_CACHE_PATH 指到本地

## Lessons Learned

- P0 是预留数据，v0.1 不参与判断，不要擅自把它拉进逻辑
- 时间唯一权威是 iPhone，绝对时间模型（warningTime = startTime + timeout）而非倒计时
- 开发永远用 30 秒测试模式，35 分钟只是参数，不是架构问题
- Shortcut 只做 NFC 入口，BLE 通信必须走原生 App，受 Core Bluetooth 后台能力限制
- iOS 后台可能终止 App，必须依赖状态保存与恢复，以及绝对时间重算
- v0.1 不碰美团接口，自动关单是 v1.0 的独立决策，避免风控和误伤真实交易
- brainstorm 源文件含私有 ChatGPT URL，public repo 必须排除（已加入 .gitignore），发布前再确认
