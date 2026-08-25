# working.md

## Changelog

### 2026-08-25（时间 21:27 后；code_review_full_audit 全部问题修复 + Issue/PR/合并落地）

按 `docs/dev/dev4/code_review_full_audit_20260825.md` 末尾「建议动作」排序逐项修复，全部落到 Yijun-Linda/beminder 公开仓库。修复按功能分组提交到 `fix/audit-beminder` 分支，共 49 个 GitHub Issue（C1 1 条 / H1-H6 6 条 / M1-M22 22 条 / L1-L21 21 条，含超时一致性矩阵问题）逐一创建，PR #1 作为全部评论载体，每个修复对应一条 PR 评论说明。

修复要点按建议动作排序：

- C1（轮换 p12 导出密码并更新 Secret）：p12 导出弱口令明文曾随 commit 0c6f3cd 推到远程 main 的 handoff_session 文档，已从 `docs/dev/dev4/handoff_session_20260824.md` 替换为占位符；真实 Team ID 与 UDID 已批量替换为占位符，`.gitignore` 补 `*.b64` 忽略规则。公开仓库配置 Secrets 前需先轮换 p12 导出密码为新值。
- H6（CI 假绿）：根部署副本 `.github/workflows/ios-sign.yml` 同步 `if-no-files-found: error`，artifact 缺失不再假绿。
- H1（BLE 后台链路）：SessionManager 状态恢复 `willRestoreState` 补 `discoverServices`，闭合后台 BLE 报警主链路。
- H2/H3（固件）：`beminder_ble.c` 去 notify 失败路径的 mbuf 双重释放；`on_state` 经 `lv_async_call` 异步投递进 LVGL 任务，消除跨线程 UI 操作。
- H4（超时单一真源）：BeminderCore 与 iOS App 统一默认 `.development`，加一致性测试断言，杜绝跨层漂移。
- H5（PRD 前台限制）：物理报警依赖 App 前台升格为一等开放风险（`docs/prd.md` 第 8.1 节），附三个缓解候选方向。

Medium/Low 逐条覆盖：M1 IPA artifact 设备标识与可再分发暴露警示、M3 ios-build paths 按独立仓库调整、M4-M7/M9/M10/M14-M16 等 iOS 与固件行为修正（BLE 广播名过滤收紧、restore 不覆盖连接状态、cancelWarning 取消孤立通知、前台通知 willPresent delegate、TimelineView 每秒刷新倒计时、state machine 转移补测等）、L14 第三方 action 固定 commit SHA、L15/L16/L18-L22 文档死链与状态声明修正、M17-M22/NFC/分发/电池预算/可复现性等约束显式化。

落地状态：49 个 Issue 已建，PR #1（`fix/audit-beminder` → `main`）已合并（squash，commit `0d606187`）。IPA 验证待续：beminder 公开仓库尚需配置 4 个签名 Secrets（`BEMINDER_TEAM_ID` / `BEMINDER_CERT_P12_B64` / `BEMINDER_CERT_P12_PASSWORD` / `BEMINDER_PROVISIONING_B64`），其中 p12 导出密码仅在用户记忆中且按 C1 应先轮换，配置完成后重新触发 `ios-sign-ipa` 工作流跑 IPA（见 `docs/dev/ios-signing-secrets.md`）。

---

### 2026-08-25 （时间 19:53 - 21:27；全量代码审查：54 文件逐文件审计，报告存 dev4）

- **产出**：`docs/dev/dev4/code_review_full_audit_20260825.md`。ocr_review preview 圈定范围后发现 beminder 的 3 个未提交变更全是 `.md`（OCR 不支持该扩展名），改走 4 个并行 subagent 分域逐文件审查（iOS 应用层 / BeminderCore 与固件 / CI 与安全 / 文档与可行性），覆盖 54 个可审文本文件，coverage 100%，Critical 与 High 结论经主会话源码级抽查复核。
- **结论速览**：Critical 1（p12 导出弱口令明文已随 commit 0c6f3cd 推到远程 main 的 handoff_session 文档，发布前必须轮换证书口令）、High 6（BLE 状态恢复断链、固件 notify 双重释放、LVGL 跨线程操作、超时默认值跨层漂移、PRD 前台限制未收敛、根部署副本 CI 假绿）、Medium 22、Low 21。本轮仅审查零修复，建议动作排序见报告末节。

### 2026-08-25（时间 18:28 - 19:32；真机测试 7 现象逆向调试 + 端到端闭环断根修复）
- **背景**：用户真机联调（iPhone beminder app + FoloToy BLE 版）报告 7 个现象，核心是进入 beminder 页面显示 RIDING、30 秒测试时间内 FoloToy 无警告声音、按钮确认后 iPhone 不停 timer（闭环后半段不通）、手机约 35 分钟后才弹"请检查美团骑行"本地通知。逆向调试（m02）后确认全部现象共享一个根因，外加两处独立问题与一处配置缺失。
- **B1 修复（commit）**：`TimeoutsConfig.currentMode` 从 `.production` 切回 `.development`（30 秒）。根因：dev3 收尾时切到 35 分钟生产模式，但真机闭环未验证就切走。iPhone 以绝对时间判断 WARNING，production 下 30 秒内不进入 WARNING，不向 FoloToy 写 WARNING 命令，FoloToy 一直停在 ACTIVE 不出声；用户按确认键时 FoloToy 状态非 WARNING，确认分支不触发，iPhone 收不到 ACK 停不了 timer。手机通知是系统本地通知兜底，独立调度照常弹出。这条链解释了"无声音 + 闭环不通 + 手机弹通知"三个现象：不是 FoloToy 声音代码坏了，是 iPhone 没在 30 秒内发 WARNING。FoloToy 侧 beminder_voice.h（beminder_voice_alert.m4a 转 16k 单声道）与 play_voice 循环逻辑完好，未改动。
- **B2 修复（commit）**：`BLEManager.didDiscover` 广播名过滤收紧。原 `guard name == advertisementName || name != nil` 恒真（任何有广播名的设备都连接），是 code_review 审计项此前未修。改为"名字存在但匹配不上 Beminder 则跳过；名字为 nil 时依赖 serviceUUID 扫描兜底"。
- **B3 记录不修**：App 后台时 WARNING 不下发 FoloToy。recomputeTimer 挂 RunLoop.main，后台挂起不执行，WARNING 命令不下发；本地通知独立触发。v0.1 对策：测试保持 App 前台，点通知唤起 App 后 resume() 补发。生产模式后台无感触发留 v0.1+ 改进。
- **C1 配置（commit）**：App logo。新建 `ios/Beminder/Assets.xcassets`，用 `beminder_logo.png`（2048x2048）生成 AppIcon（1024x1024）与 `beminder_logo` imageset；project.yml 配 `ASSETCATALOG_COMPILER_APPICON_NAME: AppIcon`；ContentView 顶部展示 logo。
- **文档（commit）**：bug 记录到 dev2/2.2（B2/B3）与 dev3/3.2（B1）Bug 追踪区；产出汇总 `docs/dev/dev4/bugs_e2e_loop_20260825.md`。
- **验证状态**：iOS 改动无法在 Windows 编译，需走 CI（ios-sign-ipa）构建后真机验证：点开始守护，保持 App 前台，30 秒后 FoloToy 红屏循环出声，按确认键后 iPhone 停 timer 进入已确认。

### 2026-08-25 续7（时间 14:29 - 16:26；Info.plist 缺 CFBundleExecutable 致 Sideloadly %%1 修复）
- **现象**：用户在 Windows 侧用 Sideloadly 装 ios-sign-ipa #3 产出的 IPA 报 `%%1`（找不到可执行文件）。
- **根因（reverse-debug，证伪 .xcodeproj 假设）**：下载该 IPA 解包，`Payload/Beminder.app/Beminder` 二进制（170KB）存在，但 embedded `Info.plist` 缺 `CFBundleExecutable` / `CFBundleName` / `CFBundlePackageType` 三项。源码 `ios/Beminder/Info.plist` 当时确实未声明这三项。用户最初怀疑缺 `.xcodeproj` 工程文件——已证伪：`ios/project.yml` 存在，CI 在 `ios-sign.yml` 里 `xcodegen generate` 即时生成 `.xcodeproj`，IPA 二进制也确实产出，故工程文件不是根因；真正缺的是 plist 里的可执行文件名声明（因 `GENERATE_INFOPLIST_FILE: NO`，XcodeGen 直接复用该 plist，构建期未自动补 `CFBundleExecutable`）。
- **修复**（commit `3441fbb`）：在 `ios/Beminder/Info.plist` 补 `CFBundleExecutable=$(EXECUTABLE_NAME)`、`CFBundleName=$(PRODUCT_NAME)`、`CFBundlePackageType=APPL`。变量在 CI 构建期解析为 `Beminder`，使三项随 plist 进入最终 `.app`。改动仅 8 行，未触碰其他逻辑。
- **验证通过（2026-08-25 16:24 run 32826411097）**：发布走普通 `git push tuzizhang99 main`（fast-forward，远程 main 为完整 mono-repo，CI 用根 `.github/workflows/ios-sign.yml`，PROJECT_DIR=`vibe-muse/beminder/ios`）。重触发 `ios-sign-ipa` 成功（run `32826411097`，~55s），下载新 IPA 解包确认 embedded `Info.plist` 含 `CFBundleExecutable = Beminder`、`CFBundleName = Beminder`、`CFBundlePackageType = APPL`，二进制 `Payload/Beminder.app/Beminder` 存在。Sideloadly %%1 根因已闭合，待用户在 Windows 侧下载该 IPA（artifact `Beminder-ipa`，保留至约 2026-09-01）经 Sideloadly 装到 iPhone 做最终实机确认。注：H2 修复（`if-no-files-found: error`）此前只落在嵌套副本 `vibe-muse/beminder/.github/workflows/ios-sign.yml`，根副本仍 `ignore`，不影响本次构建但建议后续同步到根副本。
- **实机装机（2026-08-25 用户侧）**：Sideloadly 装 run 32826411097 的 IPA 到 iPhone 13 mini 成功，App 能打开但首次启动被 iOS 拦截：提示 “developer mode required … this app will not be available for use”。这是 iOS 16+ 对 sideload/开发证书的固有要求，非构建问题。设备端开启：设置 → 隐私与安全性 → 开发者模式（安装开发 App 后才出现）→ 打开 → 重启 → 重启后弹窗确认开启。开启后 App 即运行；开发者模式常驻，不随重装消失。该要求对免费档 sideload 无法用构建开关绕过，要免此步需走 TestFlight/App Store（付费 $99 计划），已记为技术债。

### 2026-08-24 续6（11:02 - 12:41；H2/H3 修复 + F2 误报更正）
- 用 ocr-review 来审计项目的代码
- **H2 修复**（commit `e742679`）：`ios-sign.yml` `if-no-files-found: ignore` → `error`。CI 在 IPA 缺失时不再假绿——artifact 步骤会直接失败，避免拿到空包还显示 Success。
- **H3 修复**（commit `b0ce17d`）：`BLEManager.swift` 新增 `private func setConnected(_:)`，把所有 `isConnected` 写入改走 `DispatchQueue.main.async`。原因：CBCentralManager 代理回调运行在自建后台队列 `com.beminder.ble` 上，`@Published` 属性须在主线程变更，否则存在跨队列数据竞争/偶发崩溃。改动覆盖 4 处 `setConnected(false)` + 1 处 `setConnected(true)`，属性声明 `var isConnected = false {` 不变。
- **F2 复核为误报**（commit `98d6174`）：重新通读 `beminder_ble.c` 发现，`beminder_ble_set_closed()` 实际已在置状态后调用 `s_state_cb(s_state)`（290-292 行），与 `beminder_apply_command` 行为一致。即 FoloToy 在本地按确认键后屏幕会正确切到"已确认"，`demo_beminder.c:94` 注释意图已被兑现。初判 F2 为真实 bug 属误报，已在 `docs/dev/code_review_ocr_delegation_20260824.md` 与 `docs/dev/dev4/handoff_20260824.md` 中更正，无需修固件。
- **实施事故记录**：H3 用 `replaceAll` 替换 `isConnected = false` 时，误将属性声明行 `var isConnected = false {` 一并改成 `var setConnected(false) {`（语法错误），已即时回正；最终提交 diff 仅含 helper + 5 个调用点替换，声明行与 HEAD 一致。
- **提交状态**：以上 3 个修复提交 + 续5 的 5 个提交共 8 个本地提交，均未 push（用户未要求 push）。下一步真机闭环由用户在 Windows 侧下载 `Beminder-ipa`（run ios-sign-ipa #3，artifact 保留至约 2026-08-31）经 sideloadly 装到 iPhone 后验证。

### 2026-08-24 续5（04:06 - 04:45；iOS 签名 CI 跑通 + 代码评审）

- **iOS 签名构建成功**：run `ios-sign-ipa #3`（commit `75870ff`）Success，55s，产出 artifact `Beminder-ipa`（50.9 KB），可下载用 sideloadly 装到 iPhone。根因修复：`SessionManager.restore()` 的 `as? TimeInterval` 强制转换解析错误（之前 `flatMap` 形参类型被推成 `TimeInterval?` 导致整段被 nil 化），改为显式 `as? TimeInterval` 后 newValue 不再是 optional，flatMap 正常解包。CI 仍带 3 条 warning（git exit 128 非致命 / brew tap 信任提示 / Node.js 20 弃用），不影响 IPA 产出。
- **描述文件临期**：`beminder-1.mobileprovision` 有效期至 2026-08-30，免费档 7 天一轮，CI 前须替换最新文件进 secrets（`BEMINDER_PROVISIONING_B64`）。
- **代码评审（ocr review Delegation Mode）**：预览 116 files changed / 66 待审，范围 `/vibe-muse/beminder`（排除 `ai-passport`，其为独立子模块）。报告存 `docs/dev/code_review_ocr_delegation_20260824.md`，严重度索引：
  - H2（中高）`ios-sign.yml:135-142` `if:always()` + `if-no-files-found:ignore` → CI 假绿，需改 `if-no-files-found: fail`。
  - F2（中，真实 bug）`beminder_ble.c:283-288` `beminder_ble_set_closed()` 未调 `s_state_cb` → FoloToy 确认后屏不刷新"已确认"（与 `demo_beminder.c:94` 注释意图不符）；最小修复补 `s_state_cb(s_state);`。
  - H3（中）`BLEManager.swift:49,123,143,151` `@Published isConnected` 在 BLE 后台队列直接写，需 `DispatchQueue.main.async`。
  - F3（中）App `SessionManager` 与 BeminderCore `GuardianMachine` 双份状态机未共享 → 漂移风险，建议共享 golden 测试向量。
  - F1（低，设计预期）`demo_beminder.c:68` `beminder_audio_init(NULL)` 为宿主挂钩，独立固件无声是预期（非 bug），接入宿主时换真实 beep 回调。
  - H1（低-中）iPhone 前台通知静音（无 `willPresent`）；F4（低-中）CJK 字体依赖。
- **本次提交（按功能分，均未 push）**：`docs/dev/ios-signing-secrets.md`（签名执行记录 + 从零到装机步骤）、`docs/dev/code_review_ocr_delegation_20260824.md`（评审报告）、`working.md`（本 Changelog）、`ai-passport/main/beminder_voice.h`（警告语音头，08-23 生成未提交，重生成后不再自带 `#include <stdint.h>` 与 `#ifndef` 守卫，依赖调用方先 include）、`docs/dev/dev4/handoff_20260824.md`（session handoff）。

### 2026-08-24 续4（03:46 - 04:06；Phase 1 前置A-2：烧录 + BLE 广播验证 PASS）

- **烧录成功**（Windows esptool v5.3.1 直写 COM3）：bootloader@0x0 / partition-table@0x8000 / app@0x10000，三镜像 hash 校验通过，RTS 硬复位重启。镜像来自 WSL 编译产物 `ai-passport/build/`（非 `.esp-tooling/flash/` 旧离线镜像），分区表为新 single-app-large 布局。
- **Boot PASS**：启动日志干净，全部外设一次 init（ES8311 / CW2017 / 背光 / 显示 / LVGL / 三键 ADC / 电池），就绪 Display=1 Button=1 Audio=1 Battery=1，无 panic/断言/看门狗。App version `8914a94-dirty`（构建时 BLE 改动尚未提交，dirty 后缀正常，固件即 BLE 版）。
- **BLE 广播 PASS**：进入 Beminder 页面触发 `beminder_ble_init`，串口日志确认 `beminder_ble: advertising started`。广播包带完整本地名 "Beminder" + 完整 Beminder Service UUID128（beminder_ble.c L159-188），iPhone BLEManager 按 service UUID 扫描即可发现；蓝牙 MAC `4c:11:ae:30:c4:e6`。
- **待办**：Phase 1 BLE 真机闭环需 iPhone + FoloToy 同机测试（iPhone 扫到 Beminder → 连接 → STATE/COMMAND 通信 → 状态迁移）；phase1b 刷新 `mobileprovision` 进 secrets + CI 签名阶段。

### 2026-08-24 续3（时间 02:29 - 03:15）
- **Phase 0a 完成**（commit 3f935f9）：新建 `ios/project.yml`（XcodeGen 单源配置：Beminder target、bundle id `com.yijun.beminder`、`GENERATE_INFOPLIST_FILE=NO` 复用现有 Info.plist、`CODE_SIGNING_ALLOWED` 透传支持免签名）+ `.github/workflows/ios-build.yml`（macos-latest 运行器：装 XcodeGen → `xcodegen generate` → iphonesimulator 无签名 build）。成功标准从「XcodeGen 能生成 xcodeproj」推进为「工程可生成 + 模拟器可 build 的最短真机验证路径」。
- **Phase 0b 完成**（commit 0b2b213）：iPhone 入口临时改为手动开始。新增 `enum SessionStartSource { manual / shortcut / nfc }` 替换裸字符串；`SessionManager.start(from:)` 签名改为枚举；`handleLaunch`→`.shortcut`、`startForegroundScan`→`.nfc`；`NFCManager` 及 SessionManager 对它的引用全部包 `#if canImport(CoreNFC)` 编译守卫（原则：capability 是工程配置、canImport 是编译守卫，不混入 DEBUG）；ContentView 主按钮从 NFC 扫描改为「开始守护」（shield.lefthalf.filled，`.manual`）。
- **Phase 1 前置A 落地**（commit d50c55a）：ai-passport 固件接入 BLE 外设，iPhone 经 NimBLE 驱动状态。
  - `sdkconfig.defaults`：启用 `CONFIG_BT_ENABLED` + NimBLE，仅 Peripheral role、单连接、关 Central/Observer 省内存（C3 无 PSRAM）。
  - 新增 `beminder_ble.c/h`：广播 Beminder Service，STATE 特征（Read+Notify）/ COMMAND 特征（Write），UUID 与 iOS BeminderConstants.swift 两端一致。
  - `demo_beminder_app.c`：移除离线自计时，状态完全由 iPhone BLE 命令回调驱动；WARNING 下 OK/UP 按键置 CLOSED 并经 BLE Notify 回传；屏幕 / 循环人声告警 / NVS done-cancel 计数保留。
  - `CMakeLists.txt`：`REQUIRES` 追加 `bt`。
- **分区扩容修复**：默认 single-app 的 factory 分区仅 1MB，接入 BLE 后镜像 0x107910（约 1.03MB）溢出 0x7910。改用 `CONFIG_PARTITION_TABLE_SINGLE_APP_LARGE=y`（factory 分区 2MB @ 0x10000，8MB Flash 富余充足）。
- **编译验证：PASS**（WSL，ESP-IDF 5.5.3 / esp32c3；删旧 sdkconfig 后 `set-target` 重新配置生效）。`build/FoloToy-AI-Passport.bin` 已生成（0x107910，分区富余 30%），随时可烧录。
- **烧录待板卡接入**：板卡当前未连接（Windows 无 COM、WSL 无 ttyUSB/ttyACM）。镜像就绪，待用户插上 USB-C 后用 Windows 本机 esptool 直写（沿用续6 的「WSL 编译 + Windows 烧录」分工）。后续 Phase 1 BLE 真机验证需 iPhone + FoloToy 同机测试。

### 2026-08-24 续2（时间 02:16 - 02:29；Phase 0 工程审计）

- **审计范围**：`ios/Beminder/`（Info.plist / ContentView / BeminderApp / SessionManager / BLEManager / NFCManager / LocationManager / NotificationHelper / Timeouts / Models / BeminderConstants）、`ios/BeminderCore/`（纯逻辑包）、`beminder/firmware/main/` 与 `ai-passport/main/`（FoloToy 真机固件）两端 BLE 协议交叉核对。
- **核心发现一：Phase 0 卡在第一步**——全仓库**无 `project.yml`、无 `*.entitlements`、无 `.github/workflows/`**。第一阶段成功标准（source + project.yml → xcodegen generate → xcodebuild build）目前缺的不是对现有东西的验证，而是把 `project.yml` 和 CI 工作流**从零写出来**。这是当前 gap 的最主要来源。
- **核心发现二：iOS 侧 BLE 依赖是干净的**。Info.plist 已含 `NSBluetoothAlwaysUsageDescription`、`UIBackgroundModes→bluetooth-central`、`beminder://` URL scheme。Core Bluetooth 中心角色**不需要 capability/entitlement**，免费档够用，故无权木文件在本阶段不是缺口。发现→连接→服务发现→特征发现→订阅 Notify→写 COMMAND 全链路已在 BLEManager。写类型两端一致：iPhone withResponse 写 1 字节，固件 COMMAND 声明 WRITE+WRITE_NO_RSP；STATE 读+Notify 反向通道对应。
- **审计暴露的三个问题**：
  1. `BLEManager.didDiscover` 的广播名过滤逻辑过宽（[L112](ios/Beminder/Core/BLEManager.swift#L112)：`name == advertisementName || name != nil`，等于任意带名设备都过；因已按 serviceUUID 扫描兜底，影响有限，但语义错误应收紧为只认 `advertisementName`）。
  2. `NFCManager` **裸 `import CoreNFC`**（[L11](ios/Beminder/Core/NFCManager.swift#L11)）。按已确认原则（canImport=编译守卫、capability=工程配置），此文件应对 `#if canImport(CoreNFC)`；且 SessionManager 持有 `private let nfcManager = NFCManager()`，包守卫需连同空实现/移除引用一起做，否则编译失败——它与入口改造是**联动改动**，不是独立项。
  3. **FoloToy 真机固件当前未跑 BLE 外设**：`ai-passport/main/` 下只有 demo_beminder_app.c / beminder_model.c / beminder_storage.c，**没有 beminder_ble.c**。板卡现在跑的是离线 OK 键触发版。即 Phase 1 的 iPhone→BLE→FoloToy 链路，iPhone 侧代码齐，但 FoloToy 侧的服务根本没广播出来。
- **三个代码改动够不够：不够，且缺口多在 iOS 代码之外**。完整第一批应分三类：① 三个改动的涟漪——除枚举 `SessionStartSource` / `start(from:)` 签名 / 按钮外，`NotificationHelper.fireStarted`（现收 String 做比较）、`SessionManager.handleLaunch` 里的 shortcut、`startForegroundScan` 里的 nfc 都要换成枚举，并连带 `NFCManager` 的 canImport 联动；② 工程生成——新建 `project.yml`、定 deployment target 与 bundle id、建 CI 工作流；③ 验证条件——`TimeoutsConfig.currentMode` 现为 production 35min，真机 BLE 测试须切 development 30s。
- **Mac Runner 分工分两段**：Phase 0 的 buildable 闭环**无需签名**（checkout → 装 XcodeGen → generate → xcodebuild iphonesimulator build）；Phase 1 的 device install 才需签名四步（从 secrets 恢复 p12+profile、建 keychain 导入、archive、exportArchive 出 IPA），之后 Windows 侧用 sideloadly 一类工具装到 iPhone。
- **证书临期事实**：`beminder.mobileprovision` 有效期至 **2026-08-30，仅剩 6 天**；免费档描述文件是 7 天一轮。无论走哪条路，签名配置的每周刷新都会成为 Phase 1 之后的固定运维动作，比任何代码改动更早决定 CI 形态。
- **收敛后的阶段划分（采纳用户 review）**：Phase 0a 写 `project.yml` + CI workflow，跑通模拟器 build（无需签名、无需 FoloToy，可立即做）；Phase 0b 把入口改造+涟漪+canImport 联动一并放进该 build；Phase 1 两个前置并行准备——`beminder_ble.c` 集成进 `ai-passport` 并烧录、刷新 `mobileprovision` 进 secrets。架构边界（Trigger/SessionManager/FoloToyTransport）确认保留为后续重构方向，本次不实现。

### 2026-08-24（时间 01:45 - 02:16；架构边界与开发顺序澄清）

- **DoD 重定义**：当前 MVP 的完成标准重新解读为——**Trigger source 可替换，但 Session lifecycle 必须真实闭环**（IDLE→ACTIVE→WARNING→ACKED/SNOOZED/CANCELLED，含计时 / BLE / 持久化）。比 NFC 本身优先级更高的是 iPhone→BLE→FoloToy 链路第一次在真实设备上跑通；BLE 尚未跑过一次时，不应被 NFC 阻塞住开发顺序。
- **入口抽象为类型**：用 `enum SessionStartSource { case manual, shortcut, nfc }` 替换裸字符串，`SessionManager.start(from: SessionStartSource)`。入口只是事件来源，不是状态机的一部分；未来可统计各来源触发次数。
- **三层边界**：第一层 Trigger（ManualTrigger / ShortcutTrigger / NFCTrigger，回答"什么要求开始一次会话"）；第二层 SessionManager（计时 / BLE / 状态持久化，回答"开始后怎么运行"）；第三层 FoloToyTransport（把 START / CANCEL / ACK / SNOOZE / STATE 发给 Passport）。未来拿到 Core NFC entitlement 只是增加一个 Trigger，核心业务不重写。
- **Core NFC 不删、不包 #if DEBUG**：它是产品未来的真实能力，不是 debug 功能。用 `#if canImport(CoreNFC)` 做编译层兼容；UI 暂不把它当默认入口即可。Release build 反而是未来真正需要 NFC 的地方。
- **Shortcuts NFC 待实验坐实**：档案上"免费 provisioning 下 Shortcuts NFC Automation 能否在无 entitlement 情况下以 beminder:// 唤起 App"列为**待真机实验的假设**（非既定事实）。实验成功则产品触感接近原始设计；失败则已拥手动 + BLE 链路，NFC 只是未解锁 Trigger。
- **云端构建改为严格反馈环**，见正文阶段划分（Phase0 工程可生成 → Phase3 BLE 才是 iOS 真机核心 → Phase4 才做 Shortcuts NFC 实验 → Phase5 仅当短路径达不到无感触发才讨论付费 $99，用实验决定花钱而非猜测）。

### 2026-08-24（时间 00:48 - 01:33）

- **确认：免费开发者档做不了 NFC**。账号为 XCODE_FREE_USER / Xcode Free Provisioning Program（Team ID 见 GitHub Secret，发布前已替换占位符）。在 Apple App ID 能力配置里，`com.yijun.beminder` 的权限列表仅 11 项（App Groups / AutoFill / Data Protection / Game Center / HealthKit / HomeKit / Increased Memory / Inter-App Audio / Mac Catalyst / Maps / Wireless Accessory Config），**没有「NFC Tag Reading / Near Field Communication」**，无法勾选。CoreNFC 标签读取能力需付费开发者计划（$99/年）。Core Bluetooth 不受此限制，只需 Info.plist 权限描述与后台模式，无需 capability 授权。
- **决策：iPhone 侧入口临时由 NFC 改为应用内手动开始**（点击开始 Guardian），保留蓝牙与计时主链路不动；先用 30 秒模式把闭环验证出来。NFC 触发标记为「需付费开发者 + App ID 开 NFC capability + 重新签描述文件」的技术债，暂不进入当前交付。
- **现状记录**：`beminder.mobileprovision` 未含 NFC entitlement；描述文件有效期至 **2026-08-30**（临期，未来 CI 前须替换最新文件）。
- **云端构建计划已定稿**（备用未执行）：GitHub Actions macos 运行器 + XcodeGen 生成工程 + 导入 p12/mobileprovision → xcodebuild archive/export → 上传 .ipa。凭证存 GitHub Secrets（p12 与 profile 转 base64 + p12 密码）。beminder 若无独立仓库，workflow 需放根仓库 `.github/workflows/`。
- **两端收敛**：FoloToy 端离线版早已用 OK 键替换 NFC 触发，如今 iPhone 侧也临时退到手动开始，两条支线都先绕开 NFC 把端到端（非 NFC 部分）跑通；产品愿景（iPhone=大脑、NFC+BLE、绝对时间权威）保持不变，见 mvp.md 补充说明。
- **安全项**：`.p12` / `.mobileprovision` 为私密凭证，已加入 `.gitignore` 防止误提交进 public 仓库。

### 2026-08-23 (09:42 - 11:18)

- **改动目标**：离线版警告从"进入警告态只响一声 beep"改为"循环播放用户录制的人声语音，直到确认键 / 延后 / 退出页面才停止"，响应"要循环响到确认、用我录的那段声音"。
- **语音源**：`beminder/beminder_voice_alert.m4a`（用户在电脑上录制的警告语音，约 1.4s）。
- **音频转换流程**：
  1. ffmpeg 将 m4a 转为 16kHz / 16bit / 单声道 PCM；
  2. 首次尝试 `-45dB` 阈值裁剪首尾静音，误删有效语音片段 → 降到 `-55dB` 并缩短静音窗口（0.05s）仍有损耗 → 最终直接采用完整音频转换，不裁剪，避免丢失发音。
  3. Python 脚本 `.esp-tooling/voice_gen_header.py` 把 PCM 生成 C 头文件，存入 `ai-passport/main/beminder_voice.h`（`BEMINDER_VOICE_SR=16000`、`BEMINDER_VOICE_NUM_SAMPLES=22400`、`static const int16_t beminder_voice[]`）。
- **代码改动（ai-passport/main/demo_beminder_app.c）**：
  - 移除原 `play_beep`；
  - 新增 `play_voice()`：校验仍处于 WARNING → 设置 16k/16bit/单声道、音量 85 → 512 样本分块 `bsp_audio_write`，内层按样本序列读完一遍，外层 `for(;;)` 循环直到状态离开 WARNING（被确认 / 延后 / 退出页面）；
  - `audio_task` 改为：WARNING 态进入 `play_voice()` 阻塞循环，非 WARNING 仅 `vTaskDelay(40ms)` 轮询，隔离在独立任务不影响按键回调与 LVGL。
- **编译（WSL 跨平台）**：Windows 挂载的 `/mnt/d` 上 ninja 卡死（9P 文件系统性能问题）→ 将工程复制到 WSL 本地 `/root/ai-passport` 编译、产物拷贝回 Windows 路径烧录；`idf.py build` 零告警。
- **烧录（Windows 直连）**：Windows 本机 esptool v5.3.1 对 COM3 直写 bootloader(0x0) / partition-table(0x8000) / app(0x10000)。
- **真机验证 PASS**：进入 WARNING（屏幕 CHECK MEITUAN 红色字）→ 循环播放用户录制语音；按确认键（OK/UP）置 ACKED 后语音立即停止；重复进出页面无卡死。
- 临时工具 `.esp-tooling/` 已加入 `beminder/.gitignore`，不进版本控制。

### 2026-08-22 续6（时间 19:00 - 20:45；设备真机测试完成（Windows 直连）

- **烧录方式修正**：不再依赖"把板子转发进 WSL 再 idf.py flash"这条曾被计划使用的路线。实际验证：固件在 WSL 编译好后，用 **Windows 本机 esptool 对 COM3 直写三个镜像**即可烧录成功——`bootloader 0x0` / `partition-table 0x8000` / `app 0x10000`，哈希校验通过，RTS 硬复位重启。WSL 编译 + Windows 烧录分工即可，无需 usbipd/USB 转发。esptool 需 Python 装不进系统目录（沙箱限制），改用 `pip install --target <项目内临时目录>` 绕开，工具落在 `beminder/.esp-tooling`（含 esptool v5.3.1 + pyserial + 临时采集脚本 monitor_preview.py / monitor_live.py）
- **芯片级复位验证**（用于 NVS 判据）：`python -m esptool --chip esp32c3 --port COM3 --before default_reset --after hard_reset read-mac` → 连上 ESP32-C3（QFN32 rev1.1，8MB XMC flash，MAC 4c:11:ae:30:c4:e4），RTS 硬复位重启
- **设备测试 6 项逐项结论**：
  1. **启动稳定 PASS**：boot log 干净（rst:0x15 USB_UART_CHIP_RESET，SPI 8MB DIO 80MHz），全部外设一次 init（I2C 扫到 ES8311 0x18 / CW2017 电量计 0x63、背光 GPIO21、ST7789P3 240x320、LVGL、ADC 三键分压校准），就绪 Display=1 Button=1 Audio=1 Battery=1，无 panic/断言/看门狗复位/重启循环
  2. **显示 PASS**：240×320 方向、配色、刷新、背光正常；主菜单含 Beminder 页
  3. **按键 PASS**：UP/DOWN/OK 可导航、可进入；OK 长按可退回主菜单
  4. **音频 PASS（含一处设计偏离）**：进入警告态 ES8311 响铃一声。注意离线版 demo 仅在**进入 WARNING 的边缘触发一次** beep（demo_beminder_app.c：`prev != WARNING && state == WARNING` → play_beep），不是 beminder 生产固件 beminder_audio.c 的"2 秒循环告警直到确认"。要循环告警需在 ai-passport 侧补，已记入待确认
  5. **NVS 持久化 PASS**：完成/取消计数在芯片**硬复位重启**后仍存在（初始 done:2/cancel:7 → 完成+取消各 1 → done:3/cancel:8 → RTS 复位后仍为 3/8，从 NVS 重新加载成功）
  6. **重复进出页面 ~20 次 PASS**：无卡顿/卡死/花屏/声音异常
- **真机行为实测坑（重要）**：
  - 绿灯亮只代表供电，不代表数据链路。USB-C 插一半时供电通、数据不通，WP 枚举不到。排查要盯设备管理器（出现 USB Serial / JTAG / COM 号）而不是绿灯
  - 板带电池（CW2017 电量计），**拔 USB 只断 USB 供电，芯片由电池持续供电不会掉电重启**，因此"NVS 掉电测试"拔 USB 无效，需真正关断（电源开关/断电池）或用芯片级复位验证
  - 板子曾出现"枚举成功（COM3）→ 中途从 USB 总线消失 → 重插恢复"，物理接触是插拔过程最脆环节
  - 该离线版 Beminder demo **不向串口打状态日志**（页面状态切换、按键事件都只驱动 LVGL UI），串口只能佐证启动与音频初始化，功能证据以实机观察为准

### 2026-08-22 续5（时间 17:27 - 18:50）

- **编译：PASS**：ESP‑IDF v5.5.3，目标芯片 esp32c3，编译零告警，生成固件 `build/FoloToy‑AI‑Passport.bin`（710KB）
- **主机测试：PASS**：`cc -std=c11 -Wall -Wextra -Werror -Imain tests/test_beminder_model.c main/beminder_model.c -o /tmp/test_beminder && /tmp/test_beminder`，程序退出码 0

### 2026-08-22 续4（时间 16:34 - 17:27）

- ESP-IDF 5.5.3 工具链安装完成并验证（闭环 39 (1)）：`idf.py --version` = ESP-IDF v5.5.3，`git describe --tags` = v5.5.3；esp32c3 为 RISC-V 核，对应工具链 `riscv32-esp-elf-gcc`（crosstool-NG esp-14.2.0_20251107，14.2.0）位于 `/root/.espressif/tools/`，另含 `openocd-esp32`、`ninja`、`cmake`。`IDF_PATH=/root/esp/esp-idf` 已写入 `/root/.bashrc`（交互 shell 自动 source export.sh，另有 `get_idf` 函数可手动刷新）。安装落在 WSL Linux 文件系统（`/root`），未放 `/mnt/d`，以避免 Windows 挂载下的符号链接 / 权限问题与构建缓慢。
- 至此 38 条 "idf.py 构建未执行" 的前提已消除：在 `ai-passport` 或 `beminder/firmware` 工程目录执行 `idf.py set-target esp32c3 && idf.py build` 即可把构建从 NOT RUN 推进到 PASS/FAIL，并验证 beminder_* 源能否正确编进固件、有无警告。构建本身尚未执行（仍为 NOT RUN），留待需要时再跑。
- 真机 `flash` / `monitor` 仍受 39 (2) 限制：需物理 FoloToy 板卡经 USB-C 接入并在 WSL 内现身为 `/dev/ttyACM0`（容器 / WSL 还需 USB 转发），之后才能 `idf.py -p /dev/ttyACM0 flash monitor`。

### 2026-08-22 续3（时间 16:12 - 16:34）

- 16:34 发现并回补文档：设计 mvp.md 时并不知道——mvp.md 原方案设定 **iPhone 作为主控、通过 BLE 与 FoloToy 交互，并以 NFC 触发启动**；但用于实现的 **ai-passport BSP 未封装 NFC / BLE 协议栈**。落到 FoloToy 端离线实现时做了如下偏离（已在 mvp.md 末尾补「离线 FoloToy 实现说明」）：① 原「iPhone 触碰 / NFC 触发」改为 **OK 键短按触发**；② 时间源由绝对时钟改为 **MCU 系统运行时间 `lv_tick_get`**（非绝对时钟）；③ 超时开发环境默认 30 秒（宏 `BEMINDER_TIMEOUT_MS`），量产 35 分钟 = 2100000 毫秒；④ 内存：板载 **无 PSRAM**，反复进出页面须确认堆内存 / 最大空闲块稳定，音频任务栈 4096 字节、蜂鸣缓冲区约 1KB。这些事实全部来自 ai-passport 仓库（sdkconfig.defaults、AI_HARDWARE_DEVELOPMENT_GUIDE.md、beminder_model.h、demo_beminder_app.c）。产品愿景（iPhone=大脑、NFC+BLE、绝对时间权威）保持不变，rfc.md 的 BLE 协议仍作为未来完整栈目标；本离线实现只是 FoloToy 端可运行脚手架，不代表放弃原架构。

### 2026-08-22 续2（时间 15:20 - 16:12）

- 在 ai-passport（FoloToy AI Passport BSP 基线）依据 beminder/docs/mvp.md 实现离线 FoloToy 版守护应用，作为新 demo 页 "Beminder" 接入 main 菜单：纯逻辑状态机（IDLE/ACTIVE/WARNING/CLOSED）+ NVS 持久化（会话与完成/取消计数、最近若干次时长，掉电不丢失）+ 三键控制（OK 启动、OK/UP 确认、DOWN 稍后/取消）+ 240×320 UI + 警告响铃（音频任务内播放，遵循 LVGL 锁与阻塞 I/O 规则）。仅复用现有 bsp_* API，未新增 components/bsp 能力。host 端纯逻辑测试用 cc 通过（tests/test_beminder_model.c）；idf.py 构建与本板真机验证因当前环境无 ESP-IDF 工具链未执行。commit ab9df04（仅任务相关文件）。注：此功能落在 ai-passport，不在 beminder 固件仓库。
- 板级测试未执行的根因：本环境缺两类东西。（1）没装 ESP-IDF 5.5.3 工具链——探测结果 idf.py 不存在、IDF_PATH 为空、连 cmake 都没有（只有 cc/gcc/python3）。按 AI_HARDWARE_DEVELOPMENT_GUIDE.md §12，编译固件需 git clone --recursive --branch v5.5.3 esp-idf + ./install.sh esp32c3 + source export.sh，再 idf.py set-target esp32c3 && idf.py build。这一项其实不依赖硬件——只要把工具链装进来，就能把 idf.py build 从 NOT RUN 推进到 PASS/FAIL，并顺带验证新增的 beminder_* 源能否正确编进固件、有无警告。（2）没有物理板卡 + 串口通路：板子需通过 USB-C 接到本机并在 Linux 里现身为 /dev/ttyACM0 之类的串口设备（WSL/容器还要做 USB 转发），之后才能 idf.py -p /dev/ttyACM0 flash monitor，去观察 240×320 屏幕文字/方向/颜色、三键电压窗口（UP/DOWN/OK 的 mV）、ES8311 响铃音高/音量、NVS 掉电后记录是否真还在、反复进出页面有无内存/任务泄漏。
- 工具链安装已启动（闭环 39 条根因 (1)）：本机 WSL2 Ubuntu 24.04（x86_64，Python 3.12.3 / git 2.43），已用 `apt` 装齐 ESP-IDF 5.5.3 构建前置——`cmake`、`ninja-build`、`python3-venv`/`python3-pip`、`ccache`、`libffi-dev`、`libssl-dev`、`dfu-util`、`libusb-1.0-0`。下一步 `git clone --recursive --branch v5.5.3 https://github.com/espressif/esp-idf.git` 落到 `/root/esp/esp-idf`，再 `./install.sh esp32c3` 把工具链下到 `/root/.espressif`；装完后 `idf.py set-target esp32c3 && idf.py build` 即可把 38 条的 idf.py 构建从 NOT RUN 推进到 PASS/FAIL，并验证 beminder_* 源能否正确编进固件。注：克隆过程曾被会话超时打断，已改为带重试 / 断点续传的脚本重跑，装完回填本条目。
- 工具链安装完成（验证与落地细节见 续4，时间 17:27）：idf.py 已为 v5.5.3，esp32c3 工具链 `riscv32-esp-elf-gcc` 就位，`IDF_PATH` 写入 `/root/.bashrc`，闭环 39 (1)。

### 2026-08-22（时间 13:30 - 14:45）
- 新增 ios/BeminderCore 纯逻辑 Swift Package，用 Windows 上的 Swift 工具链跑 swift test 验证状态机，脱离对 Xcode / Apple 框架的依赖。抽取的原语：SessionState（IDLE/ACTIVE/WARNING/CLOSED）、GuardianMode + TimeoutsConfig（30s / 35min）、Session（绝对时间 + remainingSeconds）、GuardianMachine（start / recompute / ack / reset，注入 now 保证确定性）。写 11 个测试全部通过（超时参数 2 个 + 状态机 9 个），覆盖：start 仅非守护时生效、recompute 绝对时间到点进 WARNING、重复触发防护、ACK 置 CLOSED、remainingSeconds 钳制非负、development 端到端闭环。两个运行要点：TimeoutsConfig.currentMode 在 Swift 6 严格并发下声明为 nonisolated(unsafe)；运行需设置 SDKROOT 指向 Platforms/6.3.3/Windows.platform/.../Windows.sdk 并把 Runtimes/6.3.3/usr/bin 加入 PATH（运行时 DLL 所在），clang 模块缓存用 CLANG_MODULE_CACHE_PATH 指到本地
- 按键映射遵循`mvp.md`第 10 节：OK / 上键 = 确认处理（ACK→CLOSED 结束）；下键 = 延后提醒（告警状态下）/ 取消守护（工作状态下）；结束状态下，OK / 上键重置为就绪状态。
- 不新增任何组件、不扩展 BSP 底层能力，全部调用现有`bsp_*`系列 API

### 2026-08-22（时间 10:30 - 11:30）

- 完成 dev1 story-1.1：iPhone 大脑基座。交付 SessionManager/Models/LocationManager/NFCManager/NotificationHelper/Timeouts/Info.plist，双入口（Shortcut NFC 自动化 + 应用内 CoreNFC）。iPhone=大脑边界保持。（无法在 Windows 编译 iOS，验证需在 Mac/Xcode 真机）
- 完成 dev1 story-1.2：绝对时间状态机。warningTime=startTime+timeout，30s/35min 参数化；UserDefaults 持久化 + resume() 重算；到点本地通知兜底
- 完成 dev2 story-2.1：FoloToy BLE 外设固件。gatt service（SERVICE/STATE/COMMAND），STATE 可读+Notify、COMMAND 可写；beminder_ble.c 收命令并按状态回调切换 UI；LVGL 四态屏幕 beminder_screens.c；demo_beminder.c 按 FoloToy demo 注册机制接入。UUID 枚举与 beminder_config.h 两端一致。修复 beminder_ble_init 声明（int）与定义（void）不一致为 void。无法在 Windows 编译 ESP-IDF，真机编译验证留在接入 FoloToy 工程时进行
- 完成 dev2 story-2.2：iPhone BLE Central。BLEManager.swift 扫描 Beminder Service、建链、订阅 STATE Notify、写 COMMAND（START/WARNING）；断线自动重连 + 状态保存恢复。SessionManager.setState 进入 ACTIVE/WARNING 时下发 BLE，连接状态同步到 session.foloToyConnected，新增反向通道 .foloToyStateDidChange 预留按钮 ACK。Info.plist 已含 bluetooth-central 后台模式。验证留 Mac/Xcode 真机
- 完成 dev3 story-3.1：FoloToy 警告展示+声音。beminder_audio.c/.h 用 FreeRTOS 定时器驱动循环告警（2s 间隔、auto-reload 不自动静音）；demo_beminder.c 进入 WARNING 出声、离开停止；WARNING 屏幕红底白字。beep 回调留宿主挂钩。验证需接入 FoloToy 工程真机
- 完成 dev3 story-3.2：按钮 ACK + 端到端闭环 + 切换 35 分钟。固件在 WARNING 下按确认键置 CLOSED 并 Notify；iOS 观察 .foloToyStateDidChange 收 ACK 停 timer + persist；TimeoutsConfig 切 .production（35min）。至此六个 story 全部完成，端到端链路串起（NFC→ACTIVE→WARNING→BLE→红屏声音→按钮 ACK→CLOSED）。真机闭环验证留接入 FoloToy 工程 + Mac/Xcode
- v0.1 MVP 六个 story 全部完成。收尾待办确认。真机验证（iOS 需要在 Mac/Xcode，固件需接入 FoloToy 工程）是后续接入工作
- 收尾：README 补构建与运行指引（iOS 真机步骤 + FoloToy 固件接入方式），全链路无架构改动

### 2026-08-22（时间 08:20 - 09:55）

- 创建 prd.md 产品需求文档，基于 brainstorm 和 mvp.md 整理
- 创建 rfc.md 架构设计文档，记录 6 个关键设计决策（ADR）与 BLE 协议
- 创建 roadmap.md 迭代路线，把 v0.1 拆成 dev1 / dev2 / dev3 三个迭代
- 创建 stories/ 六个 story 文件（story-1.1 到 story-3.2）
- 创建 docs/dev/ 下 dev1、dev2、dev3 六个迭代文档，含 Bug 追踪区
- 创建 AGENTS.md、README.md、.gitignore、.env.example
- 确认 repo 属性为 public，README 已声明 publishable
- 将 brainstorm_beminder_20260822.md 加入 .gitignore，其内含私有 ChatGPT 会话 URL
- 确认 docs 迭代文档采用 docs/dev/devN/ 嵌套结构，同步修正 stories、roadmap、prd、AGENTS.md、README 中的引用
- 将 beminder 文档按功能分类分 6 次提交进 tuzizhang99 大仓库（beminder 先放进 tuzizhang99 大仓库提交，将来真要公开发布时，用 git subtree push --prefix=vibe-muse/beminder （这是工作区已有的发布模式）或 git filter-repo 把 beminder 的历史单独抽出来即可，现在不损失任何东西。）
- commit docs(beminder)：把产品文档移动进 docs/ 目录
- commit chore(beminder)：scaffold ios/ 与 firmware/，先立两端共享 BLE 协议常量（BeminderConstants.swift 与 beminder_config.h，UUID/枚举完全一致）

## Lessons Learned

- P0 是预留数据，v0.1 不参与判断，不要擅自把它拉进逻辑
- 时间唯一权威是 iPhone，绝对时间模型（warningTime = startTime + timeout）而非倒计时
- 开发永远用 30 秒测试模式，35 分钟只是参数，不是架构问题
- Shortcut 只做 NFC 入口，BLE 通信必须走原生 App，受 Core Bluetooth 后台能力限制
- iOS 后台可能终止 App，必须依赖状态保存与恢复，以及绝对时间重算
- v0.1 不碰美团接口，自动关单是 v1.0 的独立决策，避免风控和误伤真实交易
- brainstorm 源文件含私有 ChatGPT URL，public repo 必须排除（已加入 .gitignore），发布前再确认
- 环境/工具链盲区：写 MVP / PRD / RFC / roadmap 等规划文档时，AI 没有提前告知硬件固件方向所需的落地前提（要装 ESP-IDF 5.5.3、Python、ESP 工具链，且 ESP-IDF Component Manager 会拉 LVGL 等大量依赖）。用户当时完全不具备该领域知识，直到真正动手实现才陆续发现要装这些东西。教训：凡是涉及具体硬件/固件的规划产出，AI 应在早期就显式列出环境、工具链与依赖的安装清单，而不是留到实现阶段才暴露。
- 设备测试阻塞 ≠ 工具链/转发问题：曾以为真机烧录必须把板子转发进 WSL（usbipd）+ idf.py，卡了很久。实际串口只需要 Windows 本机有 COM 号，esptool 直写即可。结论：编译环境与烧录通路可以分开，别让"编译环境必须能摸到板子"这种隐含假设挡住设备测试。
