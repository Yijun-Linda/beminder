# Story 2.1：FoloToy BLE 外设（Beminder Service）

- story id：story-2.1
- 所属迭代：dev2
- 派生自：roadmap:v0.1
- 状态：已完成
- 关联迭代文档：docs/dev/dev2/2.1-folotoy-ble-peripheral.md

## 目标

FoloToy 作为 BLE（Bluetooth Low Energy，低功耗蓝牙）外设（Peripheral），广播 Beminder Service，接收 iPhone 写入的状态，并根据状态切换屏幕显示。

## 需求条目（可测试）

- R2.1.1 广播 Beminder Service，包含 STATE 和 COMMAND 两个特征值
- R2.1.2 STATE 特征值取值：0x00 IDLE，0x01 ACTIVE，0x02 WARNING，0x03 CLOSED
- R2.1.3 COMMAND 特征值支持：START，WARNING，RESET
- R2.1.4 收到 ACTIVE 时屏幕显示骑行守护中
- R2.1.5 收到 WARNING 时屏幕切换为警告页面
- R2.1.6 可被 iPhone 发现并连接

## 技术要点

- 作为 LVGL demo 页面实现，遵循 FoloToy 固件的 demo 注册机制（enter / exit / key 接口）
- 固件文件按 FoloToy 开源工程结构放置
- 协议定义见 rfc.md 第 7 节

## 相关文件路径

- 固件 demo 页面：firmware/main/demo_beminder.c（对应 FoloToy 开源工程 main/demo_<feature>.c）
- BLE service 定义：firmware/main/beminder_ble.c
- LVGL 页面：firmware/main/ui/beminder_screens.c

## 任务完成情况

- [x] BLE service 与特征值定义
- [x] STATE / COMMAND 读写逻辑
- [x] ACTIVE / WARNING 屏幕切换
- [x] 可被扫描发现并连接

## 验收标准

iPhone 能发现 FoloToy，写入 ACTIVE 后屏幕显示骑行守护中，写入 WARNING 后切换警告页面。
