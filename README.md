# SlidePlay — 纯本地的"抖音式"本地视频播放器

iOS 17+ / SwiftUI + AVKit。选择一个文件夹，上下滑动全屏播放其中的视频，
播放时屏幕上没有任何按钮，所有功能走手势或左边缘抽屉菜单。完全离线，不申请相册权限。

## 功能

- 全屏竖向翻页播放（MP4 / MOV / M4V，自动跳过 MKV 等不支持格式）
- 单击播放/暂停；双击左/右侧 ±10 秒；长按临时 2 倍速
- 左半横向拖动调亮度，右半横向拖动调音量（竖向留给翻页）
- 底部横向拖动出进度条，松手消失
- 顺序 / 随机（随机顺序固定，可手动"重新洗牌"）；全部 / 只看收藏
- 收藏（按文件唯一 ID 记录，重命名/移动不丢）
- 每个视频记忆观看进度，自动续播
- 播完自动下一个；单个循环 / 列表循环
- 倍速 0.5–3.0；画面比例 适配/填充(模糊背景)/拉伸
- 定时停止播放（15/30/45/60 分钟）
- 锁屏与控制中心播放控制；屏幕常亮；支持横屏
- **多文件夹**：可记住多个文件夹，在菜单里随时切换
- **九宫格选片**：缩略图网格直接跳播任意视频
- **排序**：按文件名 / 修改时间 / 大小
- **隐私锁**：Face ID 解锁，切回前台自动上锁（可在菜单开关）
- 文件夹书签持久化：只选一次，以后自动打开
- 适配灵动岛机型：视频铺满全屏，手势避开灵动岛

## 目录结构

```
App/            App 入口、音频会话
Models/         视频条目、播放列表(顺序/随机/排序)、收藏与进度持久化、多文件夹书签与扫描
Player/         播放引擎（当前页、设置、HUD、定时停止、锁屏命令）、隐私锁
Views/          翻页容器、单页播放器、手势层、侧边菜单、九宫格选片、引导页
Support/        Info.plist
.github/        GitHub Actions 打 IPA 的工作流
project.yml     XcodeGen 工程描述（工程文件不入库，本地生成）
```

## 本地开发（Windows 写码，Mac 生成工程）

工程文件用 XcodeGen 生成，不提交 .xcodeproj：

```bash
brew install xcodegen
xcodegen generate
open SlidePlay.xcodeproj
```

Windows 上用任意编辑器改代码即可；SwiftUI/UIKit 代码需要在 Mac 上编译验证，
推荐直接推 GitHub 让 Actions 编译（见下），或用 xtool 部署到 iPhone 真机。

## 构建与签名（推荐：CI 出未签名包，本机自己签）

普通 iPhone 必须签名才能安装，但签名不必放在 CI 里。推荐流程：

1. 新建私有仓库，把本目录全部文件推上去。
2. 把 `project.yml` 里的 `com.sian.SlidePlay` 改成你自己的 Bundle ID。
3. 在 Actions 点 "Run workflow"（或打 `v*` tag）→ 下载产物 `SlidePlay-unsigned.ipa`。
   （这个工作流不需要任何 Secret。）
4. 在 Windows 上用自己的开发者证书签名：
   - **直接装到手机**：用 Sideloadly（USB 连手机），填入你的 `.p12` 证书 + `.mobileprovision`，它会签名并安装。
   - **只要一个签名后的 .ipa**（上传 TestFlight / 分享）：用命令行工具 zsign：
     `zsign -k cert.p12 -p <p12密码> -m profile.mobileprovision -o signed.ipa SlidePlay-unsigned.ipa`
     （具体参数以 `zsign -h` 为准。）
5. 描述文件怎么选：
   - 直接装自己的手机：用 **Development / Ad Hoc** 描述文件（需包含设备 UDID）。
   - 走 TestFlight：用 **App Store** 描述文件，签名后在 App Store Connect 上传。

> 证书私钥（.p12）必须在某台 Mac 的钥匙串里生成一次；之后签名都在 Windows 做，不再需要 Mac。

### 备选：让 CI 直接签好
若想 CI 直接产出可安装的签名 IPA，改用带签名的工作流版本，并在仓库 Secrets 里配
`CERT_P12_B64 / CERT_PASSWORD / PROFILE_B64`，同时改 `ExportOptions.plist` 的 Bundle ID 与 Team ID。

## 安装 IPA

- **TestFlight**（推荐）：把 IPA 通过 App Store Connect 上传，内部测试无需审核即可安装。
- **AltStore / Sideloadly**：用 Apple ID 直接签名安装到手机（免费账号 3 个 App、7 天有效）。

## 已知限制

- MKV / AVI 无法播放（AVPlayer 不支持），列表会自动跳过这些文件。
- 文件夹在 iCloud Drive 且未下载时，播放会触发系统下载该文件。
- 若更换文件夹，收藏与进度仍按文件 ID 保留，不会串。
