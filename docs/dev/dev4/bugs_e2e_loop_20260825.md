# 真机测试 Bug 汇总：端到端闭环与警告声音

- 日期：2026-08-25
- 场景：iPhone（beminder app）＋ FoloToy（ai-passport BLE 版）真机联调
- 状态：已修复（B1/B2）＋ 记录不修（B3）

## 背景

用户在真机上验证 v0.1 端到端闭环时报告了 7 个现象，核心是：进入 beminder 页面显示 RIDING、30 秒测试时间内 FoloToy 无警告声音、按钮确认后 iPhone 不停 timer（闭环后半段不通）。手机在约 35 分钟后弹出"请检查美团骑行"本地通知。逆向调试后确认，这些现象共享一个根因，外加两处独立问题与一处配置缺失。

## 根因链条（最重要的一条）

`TimeoutsConfig.currentMode` 在 dev3 收尾时被切到了 `.production`（35 分钟），但真机闭环当时并没有验证过。iPhone 以绝对时间判断 WARNING，production 模式下 30 秒内根本不会进入 WARNING，自然不向 FoloToy 写 WARNING 命令。FoloToy 一直停在 ACTIVE（RIDING），不出声；用户按确认键时 FoloToy 状态不是 WARNING，`demo_beminder_app_key` 的确认分支不触发，FoloToy 不置 CLOSED 不 Notify，iPhone 收不到 ACK 停不了 timer。手机通知是系统本地通知兜底，由 UNUserNotificationCenter 独立调度，与 App 进程无关，所以照常弹出。

这条链解释了现象 3、4、7 的全部表现：不是 FoloToy 声音代码坏了，而是 iPhone 根本没在 30 秒内发 WARNING。

## Bug 清单

### B1（修复）：TimeoutsConfig.currentMode 误留 production

现象：30 秒内 FoloToy 无警告声音、按确认键闭环不通；35 分钟后才弹手机通知。

根因：dev3 收尾时把模式切到 production，真机闭环未验证就切走。

修复：切回 `.development`（30 秒测试模式，rfc ADR-004）。开发阶段永远用 30 秒。

归属：docs/dev/dev3/3.2-button-ack-e2e.md Bug 追踪区

### B2（修复）：BLEManager didDiscover 广播名过滤过宽

现象：`guard name == advertisementName || name != nil` 恒真，任何有广播名的设备都会被连接。

根因：意图是"广播名取不到就回落 service 过滤"，写成 `|| name != nil` 后永远为真。code_review 审计项，此前未修。

修复：收紧为"名字存在但匹配不上 Beminder 则跳过；名字为 nil 时依赖 serviceUUID 扫描兜底"。

归属：docs/dev/dev2/2.2-iphone-ble-central.md Bug 追踪区

### B3（记录不修）：App 后台时 WARNING 不下发 FoloToy

现象：iPhone 锁屏进入后台后到点，只有本地通知弹出，FoloToy 不红屏不出声。

根因：recomputeTimer 挂在 RunLoop.main，后台挂起不执行，WARNING 命令不下发。这是 ADR-002/003 绝对时间模型下的真实局限。

对策：v0.1 测试保持 App 前台；点通知唤起 App 后 resume() 会补发。生产模式后台无感触发留作 v0.1+ 改进。

归属：docs/dev/dev2/2.2-iphone-ble-central.md Bug 追踪区

## 配置项（非 bug）

### C1：App 无图标 / 无 logo

现象：主屏幕无 App 图标，app 内界面无 logo。

修复：新建 Assets.xcassets，用 `beminder_logo.png`（2048x2048）生成 AppIcon（1024x1024）与 `beminder_logo` imageset；project.yml 配置 `ASSETCATALOG_COMPILER_APPICON_NAME`；ContentView 顶部展示 logo。

## 验证状态

iOS 改动无法在 Windows 编译，需走 CI（GitHub Actions ios-sign-ipa）构建后在 iPhone/FoloToy 真机验证：点开始守护，保持 App 前台，30 秒后 FoloToy 红屏循环出声，按确认键后 iPhone 停 timer 进入已确认。
