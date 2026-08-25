# Beminder 代码评审报告（ocr review Delegation Mode）

- 生成日期：2026-08-24
- 评审范围：`<WIN-MNT>/<PRIVATE-WS>/vibe-muse/beminder`（iOS App、BeminderCore、FoloToy 固件、CI 配置）
- 评审方法：ocr_review `--preview` 预览 → 规则（严重度分级 + bestpractice_ai_debugging_diagnosis 视角）→ 差异/文件通读 → 按严重度汇报
- 预览结果：116 files changed（+13470 / -923），待审查 66 files
- 排除范围：`vibe-muse/ai-passport/`（不在本次 `/vibe-muse/beminder` 范围，且为独立子模块）

## 验证基线（先对齐设计再下结论）
- 职责边界（rfc ADR-002 / 项目 AGENTS.md 兼容约束）：iPhone 是时间唯一权威（大脑），FoloToy 只收命令切屏+声音（身体），不自行计时。
- story-3.1 目标：FoloToy 收 WARNING → 红屏 + 循环出声，直到确认。**beep 回调按设计留宿主挂钩**（`beminder_audio_init(NULL)`，dev3/3.1 changelog 明确记录）→ 独立固件无声是预期，非缺陷。
- story-3.2 目标：WARNING 且按确认键 → `beminder_ble_set_closed()` 置 CLOSED 并 Notify；iPhone 收 ACK 停 timer。真机闭环验证明确"留在接入 FoloToy 工程 + Mac/Xcode 环境"。
- 状态枚举三处须一致：App `BeminderConstants.SessionState`、BeminderCore `SessionState`、固件 `beminder_config.h`（均 0x00-0x03，命令 0x01-0x03）。当前一致。

## Part 1 — iOS App + CI（manual review）
### H2（中高）CI 假绿 — `ios-sign.yml:135-142`
`Upload IPA` 步骤 `if: always()` 且 `if-no-files-found: ignore`：即使前面 build/sign 失败，该步仍跑且不报错 → 工作流整体可能显示绿色，但并无 IPA 产出。结合 run `32677595491`/`32685422614` 已失败，这是"假绿"风险，会掩盖真实构建失败。
建议：`if-no-files-found: fail`，或仅在前置步骤成功时（`if: success()`）上传。

### H3（中）BLE 并发写 @Published — `BLEManager.swift:49,123,143,151`
`isConnected` 在 BLE 后台队列（`didDisconnectPeripheral`/`didConnectPeripheral`）直接赋值 `@Published`，无 `DispatchQueue.main.async` 包裹；而 `startScan`/`stopScan`/`connect` 内部已 `DispatchQueue.main.async`。跨队列写 published 属性存在数据竞争（Swift 6 严格并发下会告警/潜在崩溃）。
建议：统一在主队列更新 UI 相关 published 属性。

### H1（低-中，已重评）iPhone 前台通知被静音
`BeminderApp.swift` 未实现 `UNUserNotificationCenterDelegate.willPresent`，`ContentView` 无 warning 红色态。原以为"红屏+声音缺失"是高危，但设计上红屏+声音是 **FoloToy 设备职责**（见 Part 2），iPhone 仅作兜底本地通知。故 iPhone 侧前台无弹窗只弱化兜底提醒，不影响主报警链路。仍建议补 `willPresent` 让前台也能看到提示。

（其余 M1-M5 / L1-L4 为低/中可选改进，已在下方统一索引收录。）

## Part 2 — BeminderCore + FoloToy 固件（本次新增通读）
### F2（中，已复核为误报）设备屏在本地确认后不切到"已确认" — `beminder_ble.c:283-288`
初判：`beminder_ble_set_closed()` 只置 `s_state=CLOSED` 并 `beminder_ble_notify()`，**未调用 `s_state_cb`**；而 `beminder_apply_command()`（iPhone 命令路径）会调用 `s_state_cb` 驱动屏幕/声音。推断：用户按确认键后 FoloToy 屏幕可能不刷新"已确认"。
**复核结论：误报。** 当前 `beminder_ble.c` 实际在 `beminder_ble_set_closed()` 置状态后**已调用 `s_state_cb(s_state)`**（见 290-292 行），与 `beminder_apply_command` 行为一致；`demo_beminder.c:94` 注释意图已被兑现。设备屏会在本地确认后正确切到"已确认"。无需修复。

### F1（低，设计预期，非缺陷）警告声为宿主挂钩 — `demo_beminder.c:68`
`beminder_audio_init(NULL)` 是**按设计留的宿主挂钩**（dev3/3.1 changelog + README 均记录）。独立固件无声是预期；接入 FoloToy 宿主时须把 beep 回调替换为实际发声函数。→ 作为**真机验证清单项**，不是代码缺陷，勿误报为 bug。
证据：`beminder_audio.c` 中 `beminder_audio_start_warning()` 在 `s_beep == NULL` 时仅 `ESP_LOGW("未接入宿主 beep 回调，FoloToy 不会发声")` 并 return，与 dev3/3.1 changelog "beep 回调留宿主挂钩" 完全一致。

### F3（中，维护性）双份状态机实现
App 用 `ios/Beminder/Core/SessionManager.swift` + `BeminderConstants.SessionState`；BeminderCore 用 `GuardianMachine.swift` + `SessionState.swift`（纯函数，便于 Windows `swift test`）。App **未 import BeminderCore**，两套逻辑靠约定保持同步。BLE 线协议（rawValue 0x00-0x03、命令字节）须在三处（App / BeminderCore / 固件 `beminder_config.h`）保持一致。当前一致，但存在漂移风险。
建议：抽共享 golden 测试向量（两端跑同一组输入→期望状态），或让 App 直接依赖 BeminderCore。

### F4（低-中）CJK 字体依赖 — `beminder_screens.c:11-12`
WARNING 文案"请检查\n美团骑行"需宿主配置含 CJK 字形的字体，否则显示方块。→ 真机验证清单项（确认 FoloToy 宿主字体含中文）。

## 统一严重度索引
| ID | 位置 | 严重度 | 对真机闭环影响 | 性质 |
|----|------|--------|----------------|------|
| H2 | ios-sign.yml:135-142 | 中高 | 可能掩盖 IPA 构建失败（拿不到包） | CI 缺陷（已修：if-no-files-found: error，待提交）|
| F2 | beminder_ble.c:283-288 | 中 | （初判）设备确认后屏不刷新"已确认" | 误报（已复核：290-292 行已调 `s_state_cb`）|
| H3 | BLEManager.swift:49,123,143,151 | 中 | 潜在数据竞争/崩溃 | 并发缺陷（已修：setConnected 走 main，待提交）|
| F3 | SessionManager vs GuardianMachine | 中 | 长期漂移风险 | 架构/维护性 |
| H1 | BeminderApp.swift / ContentView | 低-中 | 仅弱化 iPhone 兜底提醒 | 体验 |
| F4 | beminder_screens.c:11-12 | 低-中 | 中文可能显示方块 | 依赖/验证项 |
| F1 | demo_beminder.c:68 | 低（设计预期）| 独立固件无声（预期）| 集成缺口（非 bug）|

## 真机闭环验证清单
1. **CI 真绿确认**：run `32685674984`（ios-sign-ipa #3）已成功产出 `Beminder-ipa` 50.9 KB；H2 已改 `if-no-files-found: error` 防止假绿，后续重跑可验证 artifact 必存在。
2. ~~F2 修复~~：（已复核为误报）固件 `beminder_ble_set_closed()` 已调 `s_state_cb`，设备屏会正确刷新"已确认"，无需修。
3. **F1 集成**：接入 FoloToy 宿主时把 `beminder_audio_init(NULL)` 换成真实 beep 回调，否则无声。
4. **F4 字体**：确认宿主 LVGL 字体含 CJK，否则中文方块。
5. **H3 并发**：已用 `setConnected(_:)` 走 `DispatchQueue.main.async` 修复 @Published 跨队列写，待提交。
6. 端到端：NFC/手动开始 → ACTIVE（写 START）→ 30s 测试模式到点 → WARNING（写 WARNING + FoloToy 红屏+出声）→ 按确认 → CLOSED（Notify + iPhone 停 timer + 设备屏"已确认"）。

## 修复建议顺序（由用户决定，非自动实施）
1. H2（CI 假绿，已修 ios-sign.yml，待提交）
2. H3（BLE 并发，已修 BLEManager.swift，待提交）
3. F3（补共享状态机测试，防漂移）
4. H1 / F4（体验与验证项）
（F2 已复核为误报，移除）

> 若实施修复，须遵守项目 AGENTS.md：在 `docs/dev/dev3/3.1-warning-display-sound.md` / `3.2-button-ack-e2e.md` 的 Bug 追踪 记录，并更新 `working.md` Changelog；小步提交、勿混入无关文件。
