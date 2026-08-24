# iOS 签名 CI 使用说明（Phase 1 前置B）

本文档说明如何在无 Mac 的情况下，用 GitHub Actions 的 macOS 运行器把 Beminder 签名成可装到 iPhone 的 IPA。配套工作流是 `.github/workflows/ios-sign.yml`。

## 背景

免费开发者档（Apple Developer Free Provisioning Program，Team `<TEAM_ID>`）没有手动下载描述文件的能力，描述文件是 Xcode 在本地自动生成、**有效期仅 7 天**。云端 CI 不跑 Xcode 图形界面，所以签名素材（证书 p12 + 描述文件）要手动导出后作为 GitHub Secrets 交给 CI。

两条路线的分工（见 working.md 续1）：Phase 0 的模拟器 build 无需签名；Phase 1 的真机安装才需要走本流程。

## 需要配置的 4 个 Secrets

| Secret 名 | 含义 | 示例 |
|---|---|---|
| `BEMINDER_TEAM_ID` | 开发者 Team ID | `<TEAM_ID>` |
| `BEMINDER_CERT_P12_B64` | Apple Development 证书私钥 p12 的 base64 | 见下文生成命令 |
| `BEMINDER_CERT_P12_PASSWORD` | 导出 p12 时设置的密码 | 你自己设的 |
| `BEMINDER_PROVISIONING_B64` | 描述文件 .mobileprovision 的 base64 | 见下文生成命令 |

`.p12` 和 `.mobileprovision` 是私密凭证，已加入 `.gitignore`，不要提交进仓库，只放进 GitHub Secrets。

## 在 Windows 上生成 base64

PowerShell 里对两个文件分别执行，把输出内容（不含换行）填进对应 Secret：

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("d:\<PRIVATE-WS>\vibe-muse\beminder\beminder.p12")) | Set-Content -NoNewline p12.b64

[Convert]::ToBase64String([IO.File]::ReadAllBytes("d:\<PRIVATE-WS>\vibe-muse\beminder\beminder-1.mobileprovision")) | Set-Content -NoNewline profile.b64
```

## 配置步骤

1. 打开仓库 Settings → Secrets and variables → Actions。
2. 依次新建上表 4 个 Secret（`p12.b64`、`profile.b64` 的内容直接粘贴，不要带换行）。
3. 确认仓库支持 macOS 运行器（GitHub Actions 对 public 仓库免费，private 仓库需配额）。

## 运行并下载 IPA

1. 仓库 Actions 页面选择 `ios-sign-ipa` 工作流，点 Run workflow（手动触发）。
2. 跑完后在本次运行页面下载 `Beminder-ipa` 构建产物，里面是 `Beminder.ipa`。

## 装到 iPhone（Windows 无 Mac）

下载 IPA 后，用侧载工具安装到已连电脑的 iPhone：

- **sideloadly**（推荐，免费、Windows 可用）：连上 iPhone → 拖入 .ipa → 输入 Apple ID 安装。要求 Apple ID 已开启「在设备上信任此电脑」，且设备 UDID 在描述文件内。
- 也可用 **AltStore / 爱思助手** 等同类工具。

免费档安装的 App 有效期 7 天（与描述文件同周期），到期需重新签名安装。

## 免费档注意事项

- **描述文件 7 天过期**：每次在 Xcode 重新生成（或到期前）都要刷新 `BEMINDER_PROVISIONING_B64`，这是 Phase 1 之后固定每周一次的运维动作。
- **证书有效期**：Apple Development 证书一般一年，到期需重新导出 p12 更新 `BEMINDER_CERT_P12_B64`。
- **设备注册**：免费档描述文件只包含已注册到账号的设备 UDID。换 iPhone 前先在 Xcode 里把新设备加入（App 首次连机时 Xcode 会自动加），否则签名出的 IPA 装不上新机。
- **NFC 能力**：免费档无法开 NFC Tag Reading，本 IPA 只有蓝牙 + 手动入口；NFC 是付费档后续能力（见 working.md 2026-08-24 记录）。

## 工作流放置说明

`ios-sign.yml` 目前位于 `vibe-muse/beminder/.github/workflows/`。若 Beminder 还在根仓库（mono-repo）拓扑下，GitHub Actions 只认仓库根目录的 `.github/workflows/`，需要把文件挪到根仓库对应位置，并把 `PROJECT_DIR` 改为 `vibe-muse/beminder/ios`；若已用 `git subtree push --prefix=vibe-muse/beminder` 抽成独立仓库，保持默认 `PROJECT_DIR: ios` 即可。

## 排查

- 报 `errSecInternalComponent` / 签名失败：keychain 未解锁或 `set-key-partition-list` 未生效，重跑时确认导入步骤日志无报错。
- 报 `No profiles for 'com.yijun.beminder' were found`：`BEMINDER_PROVISIONING_B64` 过期或与 bundle id 不匹配，刷新描述文件后重试。
- 导出的 IPA 装不上：确认设备 UDID 已在描述文件内（免费档需先连 Xcode 注册）。

## 从零到装机的执行顺序（2026-08-24 更新）

当前签名素材与 base64 均已就绪，直接按下面顺序执行即可，无需再生成 base64。

1. 确认素材：新描述文件 `beminder-1.mobileprovision`，有效期到 2026-08-30，已含设备 UDID `<DEVICE_UDID>`。`.esp-tooling/p12.b64` 与 `.esp-tooling/profile.b64` 已生成且与当前 p12、新描述文件字节一致。
2. 放 workflow：本仓库是 mono-repo（GitHub 根目录是 `d:\<PRIVATE-WS>`），GitHub Actions 只认根目录 `.github/workflows/`。把 `vibe-muse/beminder/.github/workflows/ios-build.yml` 与 `ios-sign.yml` 复制到根目录 `.github/workflows/`，并把两个文件的 `PROJECT_DIR` 从 `ios` 改为 `vibe-muse/beminder/ios`。
3. 提交推送：只 add 上述 workflow 文件（beminder 代码已全部提交，根目录其余改动与本部署无关），push 到 <PRIVATE-WS> 远程 main。
4. 配 4 个 Secrets：仓库 Settings → Secrets and variables → Actions，新建 `BEMINDER_TEAM_ID`（<TEAM_ID>）、`BEMINDER_CERT_P12_B64`（p12.b64 内容）、`BEMINDER_CERT_P12_PASSWORD`（导出 p12 时设的密码）、`BEMINDER_PROVISIONING_B64`（profile.b64 内容）。粘贴内容不要带换行。
5. 触发：Actions 页选 `ios-sign-ipa`，点 Run workflow，等待各步骤通过。
6. 下载：运行完成后在本次运行页面下载 `Beminder-ipa` 构建产物（Beminder.ipa）。
7. 安装：Windows 上用 sideloadly，iPhone 连电脑并信任，拖入 IPA 用 Apple ID 安装。
8. 验证：打开 Beminder，手动开始守护，FoloToy 屏幕从 READY 变 RIDING，到点变 WARNING 响铃，按 OK 变 ACKED，真机闭环打通。
