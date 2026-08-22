# Story 3.1：FoloToy 警告展示 + 声音

- story id：story-3.1
- 所属迭代：dev3
- 派生自：roadmap:v0.1
- 状态：待开发
- 关联迭代文档：docs/dev/dev3/3.1-warning-display-sound.md

## 目标

FoloToy 收到 WARNING 后，屏幕显示警告页面并播放声音，直到用户确认。

## 需求条目（可测试）

- R3.1.1 收到 WARNING 时屏幕显示警告内容（请检查美团骑行）
- R3.1.2 收到 WARNING 时播放提示音
- R3.1.3 警告页面持续显示，直到用户按键确认
- R3.1.4 未确认时不自动静音

## 技术要点

- 在 story-2.1 的固件基础上补充声音输出
- 警告是持续状态，不是一次性通知，见 mvp.md 第 9 节
- 屏幕和声音的视觉呈现不依赖 iPhone 实时驱动

## 相关文件路径

- 固件 demo 页面：firmware/main/demo_beminder.c（待创建）
- 声音输出：firmware/main/beminder_audio.c（待创建）

## 任务完成情况

- [ ] WARNING 页面显示
- [ ] 提示音播放
- [ ] 持续显示直到确认
- [ ] 未确认不静音

## 验收标准

写入 WARNING 后，FoloToy 红屏并出声，用户不按键就持续提醒。
