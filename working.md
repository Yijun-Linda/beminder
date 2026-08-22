# working.md

## Changelog

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
- 将 beminder 文档按功能分类分 6 次提交进 <PRIVATE-WS> 大仓库（beminder 先放进 <PRIVATE-WS> 大仓库提交，将来真要公开发布时，用 git subtree push --prefix=vibe-muse/beminder （这是工作区已有的发布模式）或 git filter-repo 把 beminder 的历史单独抽出来即可，现在不损失任何东西。）
- commit docs(beminder)：把产品文档移动进 docs/ 目录
- commit chore(beminder)：scaffold ios/ 与 firmware/，先立两端共享 BLE 协议常量（BeminderConstants.swift 与 beminder_config.h，UUID/枚举完全一致）

### 2026-08-22 续1（时间 10:30 - 11:30）

- 完成 dev1 story-1.1：iPhone 大脑基座。交付 SessionManager/Models/LocationManager/NFCManager/NotificationHelper/Timeouts/Info.plist，双入口（Shortcut NFC 自动化 + 应用内 CoreNFC）。iPhone=大脑边界保持。（无法在 Windows 编译 iOS，验证需在 Mac/Xcode 真机）
- 完成 dev1 story-1.2：绝对时间状态机。warningTime=startTime+timeout，30s/35min 参数化；UserDefaults 持久化 + resume() 重算；到点本地通知兜底
- 完成 dev2 story-2.1：FoloToy BLE 外设固件。gatt service（SERVICE/STATE/COMMAND），STATE 可读+Notify、COMMAND 可写；beminder_ble.c 收命令并按状态回调切换 UI；LVGL 四态屏幕 beminder_screens.c；demo_beminder.c 按 FoloToy demo 注册机制接入。UUID 枚举与 beminder_config.h 两端一致。修复 beminder_ble_init 声明（int）与定义（void）不一致为 void。无法在 Windows 编译 ESP-IDF，真机编译验证留在接入 FoloToy 工程时进行
- 完成 dev2 story-2.2：iPhone BLE Central。BLEManager.swift 扫描 Beminder Service、建链、订阅 STATE Notify、写 COMMAND（START/WARNING）；断线自动重连 + 状态保存恢复。SessionManager.setState 进入 ACTIVE/WARNING 时下发 BLE，连接状态同步到 session.foloToyConnected，新增反向通道 .foloToyStateDidChange 预留按钮 ACK。Info.plist 已含 bluetooth-central 后台模式。验证留 Mac/Xcode 真机
- 完成 dev3 story-3.1：FoloToy 警告展示+声音。beminder_audio.c/.h 用 FreeRTOS 定时器驱动循环告警（2s 间隔、auto-reload 不自动静音）；demo_beminder.c 进入 WARNING 出声、离开停止；WARNING 屏幕红底白字。beep 回调留宿主挂钩。验证需接入 FoloToy 工程真机
- 完成 dev3 story-3.2：按钮 ACK + 端到端闭环 + 切换 35 分钟。固件在 WARNING 下按确认键置 CLOSED 并 Notify；iOS 观察 .foloToyStateDidChange 收 ACK 停 timer + persist；TimeoutsConfig 切 .production（35min）。至此六个 story 全部完成，端到端链路串起（NFC→ACTIVE→WARNING→BLE→红屏声音→按钮 ACK→CLOSED）。真机闭环验证留接入 FoloToy 工程 + Mac/Xcode
- v0.1 MVP 六个 story 全部完成。收尾待办确认。真机验证（iOS 需要在 Mac/Xcode，固件需接入 FoloToy 工程）是后续接入工作
- 收尾：README 补构建与运行指引（iOS 真机步骤 + FoloToy 固件接入方式），全链路无架构改动

### 2026-08-22 续2（时间 13:30 - 14:45）
- 新增 ios/BeminderCore 纯逻辑 Swift Package，用 Windows 上的 Swift 工具链跑 swift test 验证状态机，脱离对 Xcode / Apple 框架的依赖。抽取的原语：SessionState（IDLE/ACTIVE/WARNING/CLOSED）、GuardianMode + TimeoutsConfig（30s / 35min）、Session（绝对时间 + remainingSeconds）、GuardianMachine（start / recompute / ack / reset，注入 now 保证确定性）。写 11 个测试全部通过（超时参数 2 个 + 状态机 9 个），覆盖：start 仅非守护时生效、recompute 绝对时间到点进 WARNING、重复触发防护、ACK 置 CLOSED、remainingSeconds 钳制非负、development 端到端闭环。两个运行要点：TimeoutsConfig.currentMode 在 Swift 6 严格并发下声明为 nonisolated(unsafe)；运行需设置 SDKROOT 指向 Platforms/6.3.3/Windows.platform/.../Windows.sdk 并把 Runtimes/6.3.3/usr/bin 加入 PATH（运行时 DLL 所在），clang 模块缓存用 CLANG_MODULE_CACHE_PATH 指到本地
- 按键映射遵循`mvp.md`第 10 节：OK / 上键 = 确认处理（ACK→CLOSED 结束）；下键 = 延后提醒（告警状态下）/ 取消守护（工作状态下）；结束状态下，OK / 上键重置为就绪状态。
- 不新增任何组件、不扩展 BSP 底层能力，全部调用现有`bsp_*`系列 API

### 2026-08-22 续2（时间 15:20 - 16:12）

- 在 ai-passport（FoloToy AI Passport BSP 基线）依据 beminder/docs/mvp.md 实现离线 FoloToy 版守护应用，作为新 demo 页 "Beminder" 接入 main 菜单：纯逻辑状态机（IDLE/ACTIVE/WARNING/CLOSED）+ NVS 持久化（会话与完成/取消计数、最近若干次时长，掉电不丢失）+ 三键控制（OK 启动、OK/UP 确认、DOWN 稍后/取消）+ 240×320 UI + 警告响铃（音频任务内播放，遵循 LVGL 锁与阻塞 I/O 规则）。仅复用现有 bsp_* API，未新增 components/bsp 能力。host 端纯逻辑测试用 cc 通过（tests/test_beminder_model.c）；idf.py 构建与本板真机验证因当前环境无 ESP-IDF 工具链未执行。commit ab9df04（仅任务相关文件）。注：此功能落在 ai-passport，不在 beminder 固件仓库。
- 板级测试未执行的根因：本环境缺两类东西。（1）没装 ESP-IDF 5.5.3 工具链——探测结果 idf.py 不存在、IDF_PATH 为空、连 cmake 都没有（只有 cc/gcc/python3）。按 AI_HARDWARE_DEVELOPMENT_GUIDE.md §12，编译固件需 git clone --recursive --branch v5.5.3 esp-idf + ./install.sh esp32c3 + source export.sh，再 idf.py set-target esp32c3 && idf.py build。这一项其实不依赖硬件——只要把工具链装进来，就能把 idf.py build 从 NOT RUN 推进到 PASS/FAIL，并顺带验证新增的 beminder_* 源能否正确编进固件、有无警告。（2）没有物理板卡 + 串口通路：板子需通过 USB-C 接到本机并在 Linux 里现身为 /dev/ttyACM0 之类的串口设备（WSL/容器还要做 USB 转发），之后才能 idf.py -p /dev/ttyACM0 flash monitor，去观察 240×320 屏幕文字/方向/颜色、三键电压窗口（UP/DOWN/OK 的 mV）、ES8311 响铃音高/音量、NVS 掉电后记录是否真还在、反复进出页面有无内存/任务泄漏。
- 工具链安装已启动（闭环 39 条根因 (1)）：本机 WSL2 Ubuntu 24.04（x86_64，Python 3.12.3 / git 2.43），已用 `apt` 装齐 ESP-IDF 5.5.3 构建前置——`cmake`、`ninja-build`、`python3-venv`/`python3-pip`、`ccache`、`libffi-dev`、`libssl-dev`、`dfu-util`、`libusb-1.0-0`。下一步 `git clone --recursive --branch v5.5.3 https://github.com/espressif/esp-idf.git` 落到 `/root/esp/esp-idf`，再 `./install.sh esp32c3` 把工具链下到 `/root/.espressif`；装完后 `idf.py set-target esp32c3 && idf.py build` 即可把 38 条的 idf.py 构建从 NOT RUN 推进到 PASS/FAIL，并验证 beminder_* 源能否正确编进固件。注：克隆过程曾被会话超时打断，已改为带重试 / 断点续传的脚本重跑，装完回填本条目。

### 2026-08-22 续3（时间 16:34）

- 16:34 发现并回补文档：设计 mvp.md 时并不知道——mvp.md 原方案设定 **iPhone 作为主控、通过 BLE 与 FoloToy 交互，并以 NFC 触发启动**；但用于实现的 **ai-passport BSP 未封装 NFC / BLE 协议栈**。落到 FoloToy 端离线实现时做了如下偏离（已在 mvp.md 末尾补「离线 FoloToy 实现说明」）：① 原「iPhone 触碰 / NFC 触发」改为 **OK 键短按触发**；② 时间源由绝对时钟改为 **MCU 系统运行时间 `lv_tick_get`**（非绝对时钟）；③ 超时开发环境默认 30 秒（宏 `BEMINDER_TIMEOUT_MS`），量产 35 分钟 = 2100000 毫秒；④ 内存：板载 **无 PSRAM**，反复进出页面须确认堆内存 / 最大空闲块稳定，音频任务栈 4096 字节、蜂鸣缓冲区约 1KB。这些事实全部来自 ai-passport 仓库（sdkconfig.defaults、AI_HARDWARE_DEVELOPMENT_GUIDE.md、beminder_model.h、demo_beminder_app.c）。产品愿景（iPhone=大脑、NFC+BLE、绝对时间权威）保持不变，rfc.md 的 BLE 协议仍作为未来完整栈目标；本离线实现只是 FoloToy 端可运行脚手架，不代表放弃原架构。

## Lessons Learned

- P0 是预留数据，v0.1 不参与判断，不要擅自把它拉进逻辑
- 时间唯一权威是 iPhone，绝对时间模型（warningTime = startTime + timeout）而非倒计时
- 开发永远用 30 秒测试模式，35 分钟只是参数，不是架构问题
- Shortcut 只做 NFC 入口，BLE 通信必须走原生 App，受 Core Bluetooth 后台能力限制
- iOS 后台可能终止 App，必须依赖状态保存与恢复，以及绝对时间重算
- v0.1 不碰美团接口，自动关单是 v1.0 的独立决策，避免风控和误伤真实交易
- brainstorm 源文件含私有 ChatGPT URL，public repo 必须排除（已加入 .gitignore），发布前再确认
- 环境/工具链盲区：写 MVP / PRD / RFC / roadmap 等规划文档时，AI 没有提前告知硬件固件方向所需的落地前提（要装 ESP-IDF 5.5.3、Python、ESP 工具链，且 ESP-IDF Component Manager 会拉 LVGL 等大量依赖）。用户当时完全不具备该领域知识，直到真正动手实现才陆续发现要装这些东西。教训：凡是涉及具体硬件/固件的规划产出，AI 应在早期就显式列出环境、工具链与依赖的安装清单，而不是留到实现阶段才暴露。
