# Beminder MVP

**版本：v0.1**
**目标平台：iPhone 13 mini / iOS 17.6.1 + FoloToy AI Passport**
**目标场景：美团共享单车结束骑行后忘记关锁**

---

## 1. MVP 定义

Beminder 是一个防止忘记结束美团共享单车订单的外部守护系统。

它不尝试自动关闭美团订单，也不依赖用户记住任何事情。

用户只需要在**开始骑车时用 iPhone 碰一下 FoloToy**。

之后：

```text
IDLE
  │
  │ NFC
  ▼
GUARDIAN ACTIVE
  │
  │ 35 min
  ▼
WARNING
  │
  │ BLE
  ▼
FoloToy 🔴 + 🔊
  │
  ▼
用户打开美团并结束订单
```

MVP 的核心假设是：

> **如果系统能够在用户忘记结束订单时，通过一个现实世界中的实体设备主动提醒用户，那么就已经解决了最核心的问题。**

---

# 2. 产品目标

### Must Have

MVP 必须能够完成：

1. iPhone 识别 FoloToy NFC。
2. NFC 触发 Beminder。
3. iPhone 记录启动时间。
4. iPhone 记录启动位置 P0。
5. Guardian 进入 ACTIVE 状态。
6. 35 分钟后进入 WARNING。
7. iPhone 通过 BLE 向 FoloToy 发送 WARNING。
8. FoloToy 显示警告并播放声音。
9. 用户可以通过 FoloToy 按钮确认。
10. 用户最终手动打开美团结束订单。

### 明确不做

MVP 暂时不实现：

* GPS 人车分离判断
* 判断用户是否已经离开自行车
* 自动识别美团骑行状态
* 自动结束美团订单
* AI 判断
* 美团接口
* 云端服务
* FoloToy 自己计算骑行时间

---

# 3. 核心架构

```text
                 ┌──────────────────┐
                 │     FoloToy      │
                 │                  │
                 │       NFC        │
                 └────────┬─────────┘
                          │
                          │ NFC
                          ▼
                 ┌──────────────────┐
                 │      iPhone      │
                 │                  │
                 │  Beminder   │
                 │                  │
                 │  start_time      │
                 │  P0              │
                 │  state           │
                 │  35 min          │
                 └────────┬─────────┘
                          │
                          │ BLE
                          ▼
                 ┌──────────────────┐
                 │     FoloToy      │
                 │                  │
                 │   ⚠️ WARNING     │
                 │       🔊         │
                 └────────┬─────────┘
                          │
                          ▼
                    用户处理订单
                          │
                          ▼
                       美团
```

核心架构原则：

> **iPhone = Brain**
> **FoloToy = Body**

---

# 4. 状态机

MVP 只有三个状态。

```text
IDLE
  │
  │ NFC detected
  ▼
ACTIVE
  │
  │ now >= warningTime
  ▼
WARNING
```

## IDLE

系统没有正在进行的 Guardian session。

FoloToy：

```text
┌───────────────┐
│               │
│      🚲       │
│               │
│     READY     │
│               │
└───────────────┘
```

---

## ACTIVE

NFC 被检测后：

```text
state = ACTIVE
startTime = now
warningTime = startTime + 35min
P0 = currentLocation
```

FoloToy：

```text
┌───────────────┐
│               │
│      🚲       │
│               │
│  骑行守护中   │
│               │
└───────────────┘
```

第一版可以显示：

```text
🚲
骑行守护中
```

**不要求 FoloToy 自己显示实时秒数。**

时间的唯一权威是 iPhone。

---

## WARNING

当：

```text
now >= warningTime
```

iPhone 将状态变成：

```text
WARNING
```

并通过 BLE：

```text
WARNING
```

发送给 FoloToy。

FoloToy：

```text
┌───────────────┐
│               │
│      ⚠️       │
│               │
│  请检查       │
│  美团骑行     │
│               │
└───────────────┘
```

同时：

**播放声音。**

此时用户拿出 iPhone：

```text
打开美团
   ↓
检查骑行订单
   ↓
结束骑行
```

---

# 5. 时间模型

MVP 不应该依赖一个简单的：

```text
sleep(35 minutes)
```

或者让 FoloToy 自己倒计时。

iPhone 保存一个绝对的 `warningTime`：

```text
startTime = now

warningTime = startTime + 35 minutes
```

状态判断：

```text
if now >= warningTime:
    state = WARNING
```

因此：

```text
ACTIVE
```

并不意味着 iPhone 必须一直运行一个 35 分钟倒计时程序。

它真正保存的是：

```text
startTime
warningTime
state
```

这样后续可以针对 iOS 后台生命周期进一步做可靠性测试。

---

# 6. P0

启动时：

```text
P0 = currentLocation
```

MVP **记录 P0，但不使用 P0 做任何判断**。

也就是说：

```text
P0
 │
 └── 暂不参与逻辑
```

这样做是为了给后续版本留下接口。

未来可以升级：

```text
35 min
   │
   ├── distance(P0, currentLocation) < 30m
   │       ↓
   │    普通 WARNING
   │
   └── distance(P0, currentLocation) > 100m
           ↓
        HIGH WARNING
```

因此 P0 是 MVP 中的**预留数据，而不是功能依赖**。

---

# 7. NFC

NFC 是 MVP 的唯一用户主动操作。

用户：

```text
开始骑车
    ↓
iPhone 碰 FoloToy
```

iPhone：

```text
NFC detected
    ↓
Beminder started
```

当前已经实测：

> iPhone 可以识别 FoloToy NFC。

因此 MVP 第一阶段不要求 FoloToy NFC 向 iPhone 传输 P0、时间或者其他动态数据。

NFC 的职责只有：

> **告诉 iPhone：用户现在要开始一次 Guardian session。**

---

# 8. BLE

BLE 是 MVP 中 FoloToy 与 iPhone 之间的通信链路。

建议 FoloToy 作为：

**BLE Peripheral**

iPhone 作为：

**BLE Central**

逻辑：

```text
iPhone
   │
   │ discover
   ▼
FoloToy
   │
   │ connect
   ▼
Beminder Service
```

---

## BLE Service

定义：

```text
Beminder Service
```

第一版只需要极少量状态。

### STATE

```text
0x00 = IDLE
0x01 = ACTIVE
0x02 = WARNING
0x03 = CLOSED
```

### COMMAND

第一版可以只定义：

```text
START
WARNING
RESET
```

实际 MVP 甚至可以进一步简化，只保留：

```text
ACTIVE
WARNING
```

---

# 9. FoloToy 行为

## 收到 ACTIVE

```text
BLE → ACTIVE
```

FoloToy：

```text
screen:
🚲
骑行守护中

sound:
none
```

---

## 收到 WARNING

```text
BLE → WARNING
```

FoloToy：

```text
screen:
⚠️
请检查
美团骑行

sound:
warning beep
```

---

## 用户确认

第一版可以使用一个按钮：

```text
按钮 1 = 处理
```

按下以后：

```text
FoloToy
    │
    │ BLE ACK
    ▼
iPhone
```

然后 iPhone 可以进入：

```text
CLOSED / ACKNOWLEDGED
```

这里第一版**不要求自动判断美团订单是否真的结束**。

按钮的意义只是：

> 用户已经看到提醒，并准备处理。

---

# 10. FoloToy 三个按钮

虽然 MVP 只需要一个按钮，但硬件已经有三个按钮，因此预留如下：

```text
Button 1
处理
```

代表：

> 我看到提醒了，我去检查美团。

```text
Button 2
稍后
```

代表：

> 我还在骑，不需要现在处理。

```text
Button 3
取消守护
```

代表：

> 这次 Guardian session 不需要继续。

第一版可以只实现 Button 1，其余按钮留给后续版本。

---

# 11. iPhone 端

iPhone 端建议最终实现成一个极小的：

**Beminder App**

它负责：

```text
NFC
 ↓
Session
 ↓
Timer / warningTime
 ↓
BLE
```

Shortcut 可以作为 NFC 入口，但**不要让 Shortcut 成为整个系统的大脑**。

最终架构：

```text
FoloToy NFC
     │
     ▼
iOS Shortcut
     │
     ▼
Beminder App
     │
     ├── startTime
     ├── warningTime
     ├── P0
     ├── state
     │
     └── BLE
           │
           ▼
        FoloToy
```

这样以后升级 GPS、人车分离等功能时，不需要推翻架构。

---

# 12. 第一阶段测试：30 秒模式

开发阶段**不能一开始就设置 35 分钟**。

否则每次修改一个 bug 都要等 35 分钟。

所以 MVP 开发模式：

```text
DEVELOPMENT_TIMEOUT = 30 seconds
```

正式模式：

```text
PRODUCTION_TIMEOUT = 35 minutes
```

测试闭环：

```text
IDLE
 ↓
iPhone 碰 FoloToy
 ↓
ACTIVE
 ↓
等待 30 秒
 ↓
WARNING
 ↓
BLE
 ↓
FoloToy
 ↓
🔴 + 🔊
```

30 秒版本完整跑通以后，只改变：

```text
30 seconds
        ↓
35 minutes
```

其他架构不变。

---

# 13. MVP 验收标准

Beminder v0.1 只有在下面这个完整闭环跑通以后，才算成功：

```text
① FoloToy NFC
      ↓
② iPhone 自动触发
      ↓
③ 创建 Guardian Session
      ↓
④ 记录 startTime
      ↓
⑤ 记录 P0
      ↓
⑥ state = ACTIVE
      ↓
⑦ 35 分钟
      ↓
⑧ state = WARNING
      ↓
⑨ iPhone BLE → FoloToy
      ↓
⑩ FoloToy 屏幕警告
      ↓
⑪ FoloToy 发声
      ↓
⑫ 用户按键确认
      ↓
⑬ 用户打开美团
      ↓
⑭ 用户结束骑行
```

**其中 ①～⑪ 是机器必须完成的部分。**

**⑫～⑭ 是人类最后完成的动作。**

---

# 14. MVP 成功标准

真正的成功不是 BLE 能不能连接。

也不是 FoloToy 能不能显示一个红色页面。

真正的成功标准是：

> **用户开始骑车以后，不需要再记得自己有一辆正在计费的自行车。**

他唯一主动做的动作：

```text
开始骑车
   ↓
碰一下 FoloToy
```

然后系统接管记忆。

35 分钟以后：

```text
FoloToy
   ↓
🔴
   ↓
声音
   ↓
用户被现实世界重新拉回来
```

这才是 Beminder 的产品价值。

---

# 15. MVP 开发顺序

我建议严格按照这个顺序，不要跨阶段。

### Phase 0：NFC 验证

```text
iPhone
 ↓
FoloToy NFC
 ↓
Shortcut
 ↓
Beminder Started
```

**暂时不做 BLE。**

成功标准：

> 碰一下 FoloToy，iPhone 可以自动启动 Guardian。

---

### Phase 1：时间验证

```text
NFC
 ↓
ACTIVE
 ↓
30 sec
 ↓
WARNING
```

先用 30 秒。

成功标准：

> 不需要再次操作手机，系统能够从 ACTIVE 自动进入 WARNING。

然后改成：

```text
35 min
```

---

### Phase 2：FoloToy BLE

实现：

```text
iPhone
 ↓
BLE
 ↓
FoloToy
```

先测试：

```text
ACTIVE
```

再测试：

```text
WARNING
```

---

### Phase 3：完整 MVP

```text
NFC
 ↓
ACTIVE
 ↓
35 min
 ↓
WARNING
 ↓
BLE
 ↓
FoloToy
 ↓
屏幕 + 声音
 ↓
按钮
 ↓
用户处理美团
```

---

# 16. 明确不进入 v0.1 的东西

```text
GPS
人车分离
Activity Recognition
美团骑行状态读取
自动打开美团
自动关闭美团订单
AI
云端
服务器
账号
```

它们全部可以作为 **v0.2+** 的扩展。

尤其是 GPS。

虽然现在已经记录：

```text
P0
```

但 MVP 完全不需要知道：

> 你是不是已经走远了。

因为 MVP 要解决的是一个更简单的问题：

> **如果一个人骑共享单车通常不会超过 35 分钟，那么 35 分钟以后用一个物理设备提醒他检查订单，能不能有效阻止忘记关车？**

这是一个可以在一天内验证的假设。

---

# 17. v0.1 的最终定义

```text
                    Beminder v0.1

                         NFC
                          │
                          ▼
                    ┌───────────┐
                    │  iPhone   │
                    │           │
                    │ startTime │
                    │    P0     │
                    │           │
                    │  +35 min  │
                    └─────┬─────┘
                          │
                          │ BLE
                          ▼
                    ┌───────────┐
                    │  FoloToy  │
                    │           │
                    │    ⚠️     │
                    │ CHECK BIKE│
                    │     🔊    │
                    └─────┬─────┘
                          │
                          ▼
                    用户处理订单
                          │
                          ▼
                         美团
```

**一句话规格：**

> **beminder v0.1 是一个 NFC 启动、iPhone 计时、BLE 通知、FoloToy 物理报警的共享单车防遗忘系统。**

而开发上的第一刀非常明确：

> **先把 35 分钟改成 30 秒，把 NFC → iPhone → BLE → FoloToy → 红屏 + 声音这条链跑通。**

一旦这个 30 秒闭环成立，35 分钟只是参数，不再是架构问题。

---

## 离线 FoloToy 实现说明（2026-08-22 补充）

> 本小节为后续补充，记录 mvp.md 在 **FoloToy AI Passport 离线实现**时的偏离与原因。产品愿景（iPhone=大脑、NFC 启动、BLE 通知、绝对时间权威）保持不变，详见 rfc.md。

### 为什么会有偏离

mvp.md 设计之初假设 iPhone 是时间唯一权威、并通过 NFC + BLE 与 FoloToy 通信。但当前用于实现的 **ai-passport BSP（ESP32-C3）未封装 NFC / BLE 协议栈**，也没有 iPhone 端参与。因此同一份 mvp 在「只有 FoloToy 板卡」的前提下只能做成离线版本。

### 具体偏离

| mvp.md 原设计 | 离线 FoloToy 实现 |
| --- | --- |
| iPhone 碰一下 / NFC 触发启动 | **OK 键短按**触发启动（NFC 触发无硬件支撑） |
| iPhone 保存绝对 `warningTime`，时间权威在 iPhone | 时间源为 **MCU 系统运行时间 `lv_tick_get`**（板载 uptime，非绝对时钟） |
| BLE 下发 WARNING / 状态切换 | 状态机直接在 FoloToy 上按 uptime 推进（ACTIVE → WARNING） |
| 用户按钮 ACK 经 BLE 回传 iPhone | 板载 OK/UP 键直接 ACK 置 CLOSED 并写入记录 |

### 超时参数

- 开发 / 测试模式：`BEMINDER_TIMEOUT_MS` 默认 **30 秒**（对应 §12 的 DEVELOPMENT_TIMEOUT）。
- 量产模式：**35 分钟 = 2100000 毫秒**（对应 PRODUCTION_TIMEOUT），仅改该宏，架构不变。

### 内存与资源边界（来自 ai-passport BSP 事实）

- 板载 **不使用 PSRAM**（ESP32-C3 仅内部 RAM），UI / 音频缓冲须保守。
- 反复进入 / 退出应用页，须确认 **堆内存、最大空闲块稳定**（无对象悬挂 / 任务泄漏）。
- 警告响铃在独立音频任务中播放：任务栈 **4096 字节**，蜂鸣 PCM 缓冲区约 **1KB**（512 采样 × 2 字节）。
- **整机电池预算（L21，缺口）**：渲染 + 广播（如启用）+ 音频同时在 ESP32-C3 上续航预期目前无处可查。ai-passport 板卡供电/功耗数据属宿主 BSP 范围，本仓未测量；进入续航敏感场景前需补一次性实测（典型负载下的电流），再据此评估"骑车数小时"的假设是否成立。

### 可复现性声明（M22，must-know）

当前真机 PASS 结论全部来自 **ai-passport 变体固件**（亦即本小节整段所指的运行产物），它由宿主工程配合本仓的 `firmware/main` 源码接入编译而成；本仓 `firmware/main` 作为一个独立 ESP-IDF 工程**尚未被编译过**（dev2/2.1 自认）。因此任何"本仓固件可直接复现真机 PASS"的表述都属推断而非实测，时间/超时宏声明指向的也是仓外宿主代码，本仓无法独立核实。公开发布叙事不得把本仓固件叙述为已测交付物；应明示"仓库固件为源码交付 + 需接入宿主工程编译验证"。README 已据此补充。

### 记录与边界

- 会话状态与完成 / 取消记录通过 **NVS** 持久化（掉电不丢失）。
- 因时间源是 uptime，重启后处于 ACTIVE / WARNING 的会话会按新 uptime 重新评估（可能立即进入 WARNING）；绝对时间的可靠性仍以未来 iPhone 端为准。
- 本离线实现是 mvp 的 **FoloToy 端可运行脚手架**，不代表放弃 NFC / BLE 产品架构；完整链路待接入 iPhone 端与 BLE 栈后按 rfc.md 打通。

### iPhone 端 NFC 受限与临时入口说明（2026-08-24 补充）

> 本小节记录 iPhone 侧在免费开发者计划下的能力限制与临时取舍。产品愿景（NFC 触发、iPhone=大脑、BLE 通知、绝对时间权威）保持不变。

- **能力限制**：账号为 Xcode Free Provisioning Program（免费档），App ID 能力列表不含 **NFC Tag Reading（Near Field Communication capability）**，CoreNFC 标签读取需付费开发者计划（$99/年）。Core Bluetooth 不受此限制，仅需 Info.plist 权限描述与后台模式键。
- **临时入口**：为先把非 NFC 的端到端闭环验证出来，iPhone 侧入口临时改为**应用内手动开始**（点击启动 Guardian），蓝牙与计时主链路不变；开发用 30 秒模式（§12），跑通后切 35 分钟。
- **技术债**：NFC 触发标记为「需付费开发者 + App ID 开启 NFC capability + 重新生成描述文件」，待升级后按 §7 / §11 / §13 的 Phase 0 恢复。
- 与 `## 离线 FoloToy 实现说明` 对应：FoloToy 端离线实现用 OK 键替换 NFC，iPhone 侧临时用手动开始替换 NFC，两条支线在闭环验证阶段都绕开 NFC，但未改变产品定义。
