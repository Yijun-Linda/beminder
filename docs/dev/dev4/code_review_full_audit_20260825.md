# Beminder 全量审查报告（OpenCodeReview delegate 模式逐文件审计）

- 生成日期：2026-08-25
- 审查范围：`<WIN-MNT>/<PRIVATE-WS>/vibe-muse/beminder`（iOS App、BeminderCore 包、ESP32 固件、CI 配置、全部文档与 stories）
- 审查方法：ocr_review preview 圈定范围 → 构建 (path, status) 清单 → 4 个并行 subagent 分域逐文件审查（iOS 应用层 / BeminderCore 与固件 / CI 与安全 / 文档与可行性）→ 主会话对全部 Critical 与 High 结论做源码级抽查复核
- 前置说明：ocr_review preview 显示 beminder 的 3 个未提交变更（AGENTS.md、docs/prd.md、working.md）均为 `.md`，被 OCR 标记 unsupported_ext（OCR 只审代码扩展名），故本报告按 delegate 协议改为多 agent 逐文件审查；三个未提交文件的 diff 已单独审阅并纳入结论
- 结论速览：Critical 1、High 6、Medium 22、Low 21；54 个可审文本文件全部 reviewed，coverage 100%；本轮仅审查，零修改

## 执行说明

工作区共 680 个变更文件，其中 beminder 子树只有 3 个未提交的 markdown 修改，其余为历史提交内容，因此本次按整项目全量审计执行而非增量 diff 审计。四个并行 agent 各自负责一个域，边界处保留少量重叠（超时常量跨三层比对、Info.plist 权限键与代码交叉核对），重叠区的发现由两个 agent 独立得出后再合并。所有 Critical 与 High 条目均经主会话读原文核实行号与内容，未采信任何未经核实的路径或结论。

安全相关发现遵循最小暴露原则：本文档不复写任何口令明文，只给位置引用。

## 审查清单与覆盖统计

| 统计项 | 数值 |
|---|---|
| total_files（可审文本文件） | 54 |
| reviewed_files | 54 |
| skipped_files | 0 |
| coverage_rate | 100% |

范围外排除项及理由：

| 类别 | 条目 | 排除理由 |
|---|---|---|
| 二进制资产 | beminder_logo.png、AppIcon.png、imageset 内 png、beminder_voice_alert.m4a | 非文本，无法静态审计 |
| trivial 元数据 | 3 个 Contents.json | 纯资产索引 |
| 本地未跟踪 | beminder.p12、两个 .mobileprovision | .gitignore 规则实测命中，git ls-files 无一入库 |
| 私有素材 | docs/dev/dev0/brainstorm_beminder_20260822.md | .gitignore 显式排除（含私有会话 URL） |
| vendored 工具链 | .esp-tooling/ | 第三方 Python 库集合，非项目代码 |
| 构建产物 | .build/、.clang-cache/ | SwiftPM 构建缓存 |

### (path, status) 清单

| path | status | path | status |
|---|---|---|---|
| AGENTS.md | reviewed（含未提交 diff） | ios/Beminder/Core/BLEManager.swift | reviewed |
| README.md | reviewed | ios/Beminder/Core/SessionManager.swift | reviewed |
| working.md | reviewed（含未提交 diff） | ios/Beminder/Core/NFCManager.swift | reviewed |
| docs/mvp.md | reviewed | ios/Beminder/Core/LocationManager.swift | reviewed |
| docs/prd.md | reviewed（含未提交 diff） | ios/Beminder/Core/NotificationHelper.swift | reviewed |
| docs/rfc.md | reviewed | ios/Beminder/Core/Models.swift | reviewed |
| docs/roadmap.md | reviewed | ios/Beminder/Core/BeminderConstants.swift | reviewed |
| docs/dev/dev1/1.1-nfc-trigger.md | reviewed | ios/Beminder/Core/Timeouts.swift | reviewed |
| docs/dev/dev1/1.2-time-state-machine.md | reviewed | ios/Beminder/Info.plist | reviewed |
| docs/dev/dev2/2.1-folotoy-ble-peripheral.md | reviewed | ios/project.yml | reviewed |
| docs/dev/dev2/2.2-iphone-ble-central.md | reviewed | ios/BeminderCore/Package.swift | reviewed |
| docs/dev/dev3/3.1-warning-display-sound.md | reviewed | ios/BeminderCore/Sources/GuardianMachine.swift | reviewed |
| docs/dev/dev3/3.2-button-ack-e2e.md | reviewed | ios/BeminderCore/Sources/Session.swift | reviewed |
| docs/dev/dev4/handoff_session_20260824.md | reviewed | ios/BeminderCore/Sources/SessionState.swift | reviewed |
| docs/dev/dev4/handoff_20260824.md | reviewed | ios/BeminderCore/Sources/Timeouts.swift | reviewed |
| docs/dev/dev4/code_review_ocr_delegation_20260824.md | reviewed | ios/BeminderCore/Tests/StateMachineTests.swift | reviewed |
| docs/dev/dev4/bugs_e2e_loop_20260825.md | reviewed | ios/BeminderCore/Tests/TimeoutsTests.swift | reviewed |
| docs/dev/ios-signing-secrets.md | reviewed | firmware/main/beminder_ble.c | reviewed |
| stories/story-1.1 至 3.2（共 6 个） | reviewed | firmware/main/beminder_ble.h | reviewed |
| .github/workflows/ios-sign.yml | reviewed（含根目录部署副本） | firmware/main/beminder_audio.c | reviewed |
| .github/workflows/ios-build.yml | reviewed（含根目录部署副本） | firmware/main/beminder_audio.h | reviewed |
| .gitignore | reviewed | firmware/main/beminder_config.h | reviewed |
| .env.example | reviewed | firmware/main/demo_beminder.c | reviewed |
| repo-state（git 历史/远程泄露扫描） | reviewed | firmware/main/demos/demo_beminder.h | reviewed |
| | | firmware/main/ui/beminder_screens.c/.h | reviewed |

未提交 diff 审查结论：docs/prd.md 的 diff 干净（删除开发代号、无悬挂引用）；working.md 的 diff 是良性的续7 时间段修正；AGENTS.md 的 diff 引入 3 处缺陷，见 M20。

---

## Critical（1）

### C1. p12 导出口令明文已推送到远程 main

- path: docs/dev/dev4/handoff_session_20260824.md
- startLine: 14　endLine: 28（另见 26 行）
- category: security　severity: critical
- content: 第 14 行用户原话写有 p12 导出密码的具体值，第 28 行在 GitHub Secrets 清单里再次记录同一弱口令（6 位数字），同一行还自称仅用户记忆不在磁盘文档明文，前后矛盾。主会话已独立复核：该文件随 commit 0c6f3cd 存在于远程 <PRIVATE-WS>/main，且远程副本可检索到该字面量两处。签名文件本身未入库，攻击者需同时拿到 p12 文件才能利用，但弱口令存在复用风险，而项目 AGENTS.md 第 6 条承诺仓库将公开发布。
- 处置建议：立即重导出 p12 并更换导出口令、更新对应的 GitHub Secret；若仓库转公开前不重写历史，至少作废当前开发证书。第 26 行的真实 Team ID 同样建议在发布前替换为占位符。

## High（6）

### H1. BLE 状态恢复链路断裂，后台报警主路径静默死亡

- path: ios/Beminder/Core/BLEManager.swift
- startLine: 138　endLine: 148
- category: defect　severity: high
- content: 蓝牙低功耗（Bluetooth Low Energy，BLE）状态恢复回调恢复了外设对象，但清空两个 characteristic 后没有任何代码重新执行 discoverServices。恢复后 didUpdateState 会走 startScanning，而已连接的 FoloToy 不再广播，didDiscover 不会触发；即使触发，115 行的 guard self.peripheral == nil 也拦截重连。结果是在 bluetooth-central 后台模式下 App 被系统杀掉再由蓝牙事件唤醒的场景里，连接活着但 commandCharacteristic 恒为 nil，send() 在 74 行静默返回，WARNING 命令永远发不到设备，这正是产品最核心的后台报警链路。
- 建议：willRestoreState 里对已连接外设直接调用 discoverServices。

### H2. NimBLE notify 失败路径双重释放

- path: firmware/main/beminder_ble.c
- startLine: 145　endLine: 155
- category: defect　severity: high
- content: ble_gatts_notify_custom 返回非 0 时调用 os_mbuf_free_chain(om)。已核对上游 mynewt-nimble 与 espressif fork 实现：notify 函数无条件接管 mbuf 所有权，失败时内部已释放。应用层再释放一次即堆损坏，触发场景真实存在（断连竞态、队列满），对需要长期驻留广播的设备致命。
- 建议：调用后不再触碰 om。

### H3. LVGL 在 NimBLE host task 上下文被直接操作

- path: firmware/main/demo_beminder.c
- startLine: 35　endLine: 47
- category: defect　severity: high
- content: beminder_on_state 由 GATT 访问回调与按键任务同步调用（beminder_ble.c 93、102、290 行），直达 beminder_screens_show 操作 lv_obj，全程未持有 LVGL port lock。LVGL 非线程安全，渲染任务并发访问同一对象树会导致偶发崩溃或界面撕裂，此类问题极难复现定位。音频部分 xTimerStart 本身线程安全不受影响。
- 建议：回调只置标志或经 lv_async_call 与队列把 UI 切换投递回 LVGL 任务上下文执行。

### H4. 超时模式默认值跨层漂移

- path: ios/BeminderCore/Sources/BeminderCore/Timeouts.swift
- startLine: 25　endLine: 28
- category: defect　severity: high（iOS 域与固件域两个 agent 独立发现，取严评级）
- content: BeminderCore 里 currentMode 默认 .production（2100 秒），宿主 App 同名文件默认 .development（30 秒），两份声称原样抽取的副本在最安全相关的参数上已经相反（两侧原文均已核实）。当前 App 未 import 该包所以是潜伏问题，但任何人把 App 切到引用此包（建包的目的），开发期超时会从 30 秒静默变成 35 分钟，端到端测试结论全部失效。三份定义没有单一真源也没有一致性断言。
- 建议：App 改为依赖 BeminderCore 包并删除本地副本，或在测试中加入对宿主常量的镜像断言。

### H5. PRD 可靠性承诺与前台限制正面冲突

- path: docs/prd.md
- startLine: 98　endLine: 98
- category: other　severity: high
- content: 已交付的报警路径只在 App 前台有效：recompute 定时器跑在 RunLoop.main（SessionManager.swift 166 至 171 行），手机锁屏入袋后 App 挂起、recompute 停止，WARNING 命令发不出去，只剩本地通知（bug 记录 B3，标注记录不修）。而 PRD 第 8 节承诺系统不能依赖用户记忆，核心价值恰是物理报警把人拉回来；35 分钟骑行中手机在兜里锁屏是主用例而非边缘情况。
- 建议：PRD、RFC、roadmap 把这个平台约束升格为一等开放风险，给出候选缓解方向（状态恢复后台 BLE 写入、通知操作确认兜底），而不是留在 dev2 bug 单里当脚注。

### H6. 部署副本 CI 假绿未修，已知问题只修了一半

- path: .github/workflows/ios-sign.yml（仓库根部署副本，GitHub Actions 实际执行的那份）
- startLine: 135　endLine: 142
- category: defect　severity: high（两个 agent 独立发现）
- content: 根副本仍是 if: always() 加 if-no-files-found: ignore 组合：IPA 导出失败时 job 照样绿、artifact 为空也不报错。修复（commit e742679 改 ignore 为 error）只落在不会被执行的 vibe-muse/beminder 子树副本上，根副本没同步。profile 将于 2026-08-30 过期，届时重跑失败会是假绿而非明确报错，直接误导下载 IPA 安装的运维链路。working.md 续7 已记录此分歧但未解决。
- 建议：把 ignore 改 error 同步到根副本，或直接以子树为准重新放置工作流。

## Medium（22）

| # | path | lines | cat | 内容摘要 |
|---|---|---|---|---|
| M1 | .github/workflows/ios-sign.yml | 135-142 | security | 签名 IPA 作为公开 Actions artifact 上传，内嵌 embedded.mobileprovision 暴露设备唯一标识符（Unique Device Identifier，UDID）与 Team ID，附赠可再分发二进制；转公开前应改私有分发渠道 |
| M2 | repo-state 多文件 | 无 | security | 真实标识符散布在已推送文档：UDID（ios-signing-secrets.md:73）、真实 Team ID（多处）、账号名、bundle id com.yijun.beminder，与 AGENTS.md 第 6 条 fake-handles 规则正面冲突；公开发布前必须批量替换 |
| M3 | .github/workflows/ios-build.yml（根副本） | 16-21 | defect | push 触发的 paths 过滤器按仓库根解析，与 mono-repo 实际路径 vibe-muse/beminder/ios 不匹配，push 到 main 永远不触发构建，只有手动 dispatch 能跑 |
| M4 | ios/Beminder/Core/BLEManager.swift | 117-122 | defect | 广播名过滤不对称：缓存名为空字符串（常见值）的正确设备会被拒，两个来源都为 nil 反而靠 serviceUUID 放行；应按 trim 后的名字判断并对 service 匹配但名字不匹配的情况记日志 |
| M5 | ios/Beminder/Core/SessionManager.swift | 90-93 | defect | 每次 didBecomeActive（含下拉通知栏收回）都整体 restore()，foloToyConnected 被重置为 false 且无新 BLE 事件纠正，已连接标识永久消失直到下次断连重连 |
| M6 | ios/Beminder/Core/SessionManager.swift | 218-223 | defect | 收到按钮确认回执（acknowledgement，ACK）进入 CLOSED 或执行 debugReset 时，不取消已调度的 warning 本地通知，提前确认后仍会准点弹出假警报；全工程没有任何 removePendingNotificationRequests 调用 |
| M7 | ios/Beminder/Core/NotificationHelper.swift | 43-53 | defect | 注释承诺前台可见提醒，但工程没有 UNUserNotificationCenter delegate 和 willPresent 实现，iOS 对前台应用默认静默投递；设计针对前台场景的兜底路径恰好失效（前次评审亦建议补 willPresent） |
| M8 | ios/project.yml | 38-51 | other | Info.plist 声明了近场通信（Near Field Communication，NFC）权限、NFCManager 完整实现，但没有 entitlements 配置，readingAvailable 恒 false，startScan 静默返回无反馈；README 列为后续能力，当前这条路实际不通且失败无声 |
| M9 | ios/Beminder/ContentView.swift | 34-38 | defect | 倒计时文本不逐秒刷新：timer 只调 recomputeStateIfNeeded，未跨阈值时不触碰 @Published session，剩余 N 秒冻结到状态跳变为止，显示长期失真 |
| M10 | firmware/main/beminder_ble.c | 98-106 | defect | switch 的 default 分支把一切未知命令字节当 RESET 直接打回 IDLE；写错一字节就在用户不知情时终止守护与告警，未知操作码应忽略并记日志 |
| M11 | firmware/main/beminder_config.h | 36-39 | security | 全链路无配对、绑定、加密：射程内任意 Central 可读 STATE、伪造 START 与 WARNING，更可直接写 RESET 远程关闭正在响的警告音，恰好绕过未确认不得自动静音的产品约束；至少 COMMAND 写入应要求加密或白名单 |
| M12 | firmware/main/demo_beminder.c | 62-71 | defect | s_ble_started 守卫漏掉 62 行的 screens_init 且 exit 为空操作，重复进入 demo 会叠出 4 个全屏容器，旧对象泄漏并停留旧状态形成重影 |
| M13 | firmware/main/demo_beminder.c | 66-68 | other | audio_init(NULL) 使 beep 回调恒空，独立固件无声属设计内（dev3/3.1 已记录宿主挂钩约定，前次评审亦确认为预期），风险在于端到端验证声明里的报警环节实际缺失，容易产生虚假信心；接入宿主前应保持此事实可见 |
| M14 | ios/BeminderCore/Sources/BeminderCore/GuardianMachine.swift | 40-43 | defect | ack 守卫允许 IDLE 进 CLOSED：无会话时收到 ACK 产出双 nil 时间戳的 CLOSED 态，UI 显示已确认，与注释语义矛盾、与固件仅 WARNING 下确认不对称；若有意容忍乱序应写注释和测试，否则收紧为仅 isGuarding |
| M15 | ios/BeminderCore/Tests/BeminderCoreTests/StateMachineTests.swift | 17-121 | testing | 未覆盖转移清单：ack 从 active/idle/closed 三种起点、reset() 四个起始状态零覆盖、warning 下 recompute 保持、closed 下 recompute 空操作、start 从 warning/closed 重开；恰是实现守卫最微妙处，建议补转移表驱动测试 |
| M16 | ios/BeminderCore/Tests/BeminderCoreTests/StateMachineTests.swift | 18、103 | testing | 测试直改全局 currentMode（TimeoutsTests 15、22 行同病），swift-testing 默认并行执行，production 断言可能与 development 断言交错产生偶发失败；需加 .serialized trait 或参数注入消除全局态 |
| M17 | docs/dev/dev1/1.1-nfc-trigger.md | 20-37 | documentation | 文档仍以已完成状态呈现双入口 NFC 设计（快捷指令自动化加 CoreNFC 按钮），现实是免费账号无法启用 Tag Reading、Phase 0b 已换成手动开始按钮；照文档配置的是一条死路 |
| M18 | stories/story-1.1.md | 34-40 | documentation | 五个 checkbox 全部勾选，其中 Shortcut 自动化为从未真机执行的步骤，验收标准在免费签名下不可达；状态已完成混淆了代码交付与功能验证，且不像 dev3/3.2 那样有推迟注记 |
| M19 | stories/story-3.2.md | 36-39 | documentation | 30 秒端到端闭环跑通的勾选被 bugs_e2e_loop_20260825.md 直接推翻（首次真机端到端正因此失败，复验仍 pending）；切换 35 分钟正式模式的勾选正是后来定位的闭环断裂回归 B1 |
| M20 | AGENTS.md（未提交改动） | 21-32 | documentation | 新工作规范三处缺陷：指向不存在的 docs/working.md（实际在项目根）、引用不存在的 docs/raw 目录、纯文档项目无需运行环境与同文件下方真实环境约束自相矛盾 |
| M21 | docs/roadmap.md | 54-70 | other | 分发可行性碎片化记录在 working.md（7 天过期、Developer Mode 门、99 美元计划才能上 TestFlight 与 NFC）但路线图从不收敛；v0.1 必备项 NFC 触发在此账号下永远无法真机兑现，付费决策点应显式写出 |
| M22 | docs/mvp.md | 886-927 | maintainability | 真机 PASS 全部来自 ai-passport 变体固件，本仓 firmware/main 从未被编译过（dev2/2.1 第 30 行自认）；README 把本仓固件当交付物却不提 ai-passport，发布叙事与被测产物之间存在可复现性断层，timeout 宏声明亦指向仓外代码无法在本仓核实 |

## Low（21）

| # | path | lines | cat | 一句话摘要 |
|---|---|---|---|---|
| L1 | ios/project.yml | 50-51 | other | CODE_SIGNING_ALLOWED 自引用赋值是无操作，注释宣称的效果不存在，误导维护者 |
| L2 | ios/Beminder/Info.plist | 4-60 | other | GENERATE_INFOPLIST_FILE=NO 后缺 UISupportedInterfaceOrientations、LSRequiresIPhoneOS 等常规注入键；sideload 路径已实证可跑，App Store 校验更严 |
| L3 | ios/Beminder/BeminderApp.swift | 22-24 | security | beminder:// 不校验 host 与 path，任意应用可静默拉起守护会话构成低成本骚扰向量，建议要求特定 host |
| L4 | ios/Beminder/Core/BLEManager.swift | 196-199 | defect | peripheral 与 characteristic 跨 BLE 队列和主线程读写无同步，Thread Sanitizer 会报的真实数据竞争，实际崩溃概率低 |
| L5 | firmware/main/beminder_ble.c | 230-234 | defect | host task 缺 nimble_port_freertos_deinit，任务函数返回属 FreeRTOS 未定义行为，将来加关机逻辑必踩 |
| L6 | firmware/main/beminder_ble.c | 240-258 | defect | nvs 与 gatts 初始化返回码全被忽略，服务注册失败仍照常广播，故障形态迷惑；GAP 与 GATT 调用顺序本身正确 |
| L7 | firmware/main/beminder_ble.c | 197-210 | maintainability | 单订阅者哨兵依赖连接句柄非 0 的隐含假设，第二个 Central 连接会覆盖首订阅者句柄导致 Notify 静默丢失 |
| L8 | firmware/main/beminder_ble.c | 33 | defect | s_state 被 host task 与按键任务跨任务读写无同步，形式上是数据竞争，建议原子操作或临界区包裹 |
| L9 | firmware/main/beminder_audio.c | 42-46 | performance | beep 回调跑在 Timer Service 任务上下文，宿主阻塞实现会拖垮全局软件定时器，该约束未写在 audio.h 契约里 |
| L10 | firmware/main/beminder_audio.c | 5-7 | style | 注释残句该提示音只在提醒资本主义不成立不通顺且 mvp.md 中无对应出处（两个 agent 独立发现），疑似生成残留 |
| L11 | .gitignore | 1-35 | security | 缺全局 *.b64 规则；教程教人在任意工作目录生成的 p12.b64 与 profile.b64 若落在项目根不会被忽略，配合历史上 git add -A 误提交模式是现成泄露路径 |
| L12 | docs/dev/dev4/handoff_session_20260824.md | 25-29 | documentation | 记录的 Secret 名与工作流实际名不一致（缺 CERT_ 中缀），下次刷新 profile 的人会配错名字，需在 GitHub Settings 核实一次并统一文档 |
| L13 | .github/workflows/ios-sign.yml | 71-83 | security | set -x 展开含密码的命令行进 job 日志，完全依赖 GitHub 对精确 Secret 值的自动打码兜底；keychain 用空口令创建 |
| L14 | .github/workflows/*.yml | 42 | security | checkout 与 upload-artifact 按 tag 引用非 commit SHA 固定，上游投毒即在持密环境执行第三方代码 |
| L15 | AGENTS.md | 3-9 | maintainability | file:///d:/ 形式的 Windows 绝对链接在 WSL 与外部读者处全是死链 |
| L16 | README.md | 9-17 | documentation | 文档导航列出根路径，实际都在 docs/ 下，导航条目无法解析；AGENTS.md 项目结构同病 |
| L17 | working.md | 158-171 | documentation | 三条 changelog 指向 805528e 已删除的扁平路径，现存活于 dev4 新家，指针未随搬迁更新 |
| L18 | docs/rfc.md | 68 | documentation | v0.1 只实现 IDLE、ACTIVE、WARNING 的范围声明落后于现实：按钮 ACK 流程要求 CLOSED 且已实现 |
| L19 | docs/dev/dev2/2.2-iphone-ble-central.md | 16 | documentation | 未定义缩写 s32（应为 story-3.2）全文无展开，新读者无法解码 |
| L20 | .env.example | 8-9 | documentation | 自称可抄的配置面实为装饰品：UUID 占位符全零非法且无任何代码读取此文件 |
| L21 | docs/mvp.md | 908-917 | other | 资源边界补篇缺 FoloToy 整机电池预算：渲染加广播加音频在 ESP32-C3 上骑数小时，续航预期无处可查 |

微瑕不再单独成条：roadmap.md 22 行的 docs/dev2/ 路径笔误（同文件相邻行均正确）、demo_beminder.c 55 至 60 行参数判空冗余。

## 超时一致性矩阵

| 常量 | BeminderCore 值 | iOS App 值 | 固件值 | 结论 |
|---|---|---|---|---|
| DEVELOPMENT_TIMEOUT_SECONDS | 30 秒 | 30 秒 | 无对应常量（固件不计时，符合 ADR-002） | 一致 |
| PRODUCTION_TIMEOUT_MINUTES | 35 分钟（2100 秒） | 35 分钟（2100 秒） | 无对应常量 | 一致 |
| currentMode 默认值 | .production（2100 秒） | .development（30 秒） | 固件按 30 秒开发节奏联调 | 不一致，见 H4 |
| 超时判定权威 | 绝对时间 warningTime，iPhone 侧 | 同左 | 无计时逻辑，仅接收命令 | 一致，职责边界成立 |
| WARNING 提示节奏 | 不适用 | 不适用 | 2000 毫秒周期（beminder_audio.c:25） | 表现层节奏，无需跨层一致 |

UUID 与枚举字节核对结论：服务 UUID 与状态字节 0x00 至 0x03、命令字节 0x01 至 0x03 在 BeminderConstants.swift、SessionState.swift、beminder_config.h 三处逐字节一致（靠人工同步，无自动断言，见 M16 关联建议）。

## 可行性与合理性总评

架构本身站得住。iPhone 是时间唯一权威、FoloToy 是只收命令的身体，职责边界清晰且被代码遵守；BLE 协议常量两端一致；PRD、RFC、MVP、roadmap、stories 描述同一套连贯故事，代码与文档匹配度高于同类个人项目的一般水平，六个 story 的需求条目几乎都能在代码里找到对应实现。

风险集中在三个层面。第一是安全卫生与公开发布承诺脱节：弱口令已推远程、真实标识符满文档，而 AGENTS.md 承诺转公开，这组问题必须先于任何公开动作处理。第二是两条核心产品链路各自带断点：手机侧后台恢复链路（H1）与设备侧告警声的宿主接入（M13）都还没真正闭合，加上 PRD 对前台限制的回避（H5），防遗忘这个标题功能在主用例下的可靠性尚未成立。第三是文档真实性债：story 与 dev 文档的完成标记多次超前于事实（M17、M18、M19），ai-passport 变体的可复现性缺口（M22）会让外部读者照着 README 复现不出真机验证过的东西。

## 建议动作排序

1. 轮换 p12 导出口令并更新对应 Secret，评估发布前是否作废当前开发证书（C1）
2. 根部署副本同步 if-no-files-found: error，消除 CI 假绿（H6）
3. willRestoreState 补 discoverServices，闭合后台报警主链路（H1）
4. beminder_ble.c 去掉失败路径的 mbuf 释放；on_state 经异步投递进 LVGL 任务（H2、H3）
5. 决定超时配置单一真源并加一致性断言（H4）
6. PRD 把前台限制升格为一等开放风险并附缓解候选（H5）
7. 公开前批量替换真实标识符为占位符（M2），补 *.b64 忽略规则（L11）

以上为本轮全部结论，仅审查未做修复。
