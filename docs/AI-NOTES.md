# 开发手记（给下一个接手的人 / AI）

这些是踩坑之后写下来的经验，不是文档的一部分，但能省下你很多时间。

## 工程与环境

- 工程路径：`NekoMusic.xcodeproj`，两个 target：`NekoMusic` 与 `NekoMusicWidgetExtension`
- 最低 iOS 16.0，无 SPM、无 CocoaPods，纯原生 SwiftUI
- 真机签名：Team `B9N6W9S7D8`，Bundle `com.wlt743.nekomusic`，**免费个人签名 7 天过期**
- 装包命令：
  ```bash
  xcodebuild -project NekoMusic.xcodeproj -scheme NekoMusic -configuration Debug \
    -destination 'id=<UDID>' -derivedDataPath build/DeviceData -allowProvisioningUpdates build
  xcrun devicectl device install app --device <UDID> build/DeviceData/Build/Products/Debug-iphoneos/NekoMusic.app
  ```
- 新增 Swift 文件必须手动登记进 `project.pbxproj`（没有 Xcode 的自动索引），否则报 `Build input file cannot be found`

## 后端

- 地址：`https://music.nekocore.cn`（`APIConfig.swift` 里唯一常量）
- 所有请求带防爬头 + `X-Neko-Nonce` PoW（SHA-256 前导零）
- **后端只认境内 IP**，测试前关掉 Clash，否则全站 409「请求已失效」
- 需要访问 GitHub 时再开代理，两者互不影响

## 布局与适配（血泪教训）

- `fullScreenCover` **不会把旋转后的尺寸传给内容**。要跨方向布局，必须在父层用 `GeometryReader` 取尺寸再显式传入
- `ViewThatFits` 按顺序挑「ideal size 放得下」的候选，多给几档降级，比手算阈值稳
- 布局族用 `horizontalSizeClass` / `verticalSizeClass` 判断，不要用宽高比（首帧可能还是旧尺寸）
- 复用的组件里如果有 `Spacer`，放进固定尺寸的容器会改变兄弟视图的布局，必要时写专用版本

## 已经放弃的东西

- **Live Activity 锁屏歌词**：`LyricLiveActivityManager.isEnabled = false`
  - `ContentState` 有 4KB 上限，图片塞 Data 必超
  - App Group 共享容器需要付费账号
  - 系统对 Live Activity 更新有节流，快速歌词会卡
  - 代码保留在工程里，想捡起来先解决上面三条
- **站内消息 SSE 实时通道**：`/api/user/notifications/stream` 经 CDN 不返回数据，改为轮询

## 工作约定

- 改完代码**双端推包**：模拟器 + 真机各一份
- 模拟器开着就别反复关，每次启动会占满 CPU；打开后等 `uptime` 的 load 降到 20 以下再操作
- 真机日志拿不到（无 root），排查用模拟器 + `simctl spawn <udid> log show --predicate 'process == "NekoMusic"'`
- token 消耗要控制，长任务先写文档再动手
- 用户手机上的 App 不要用程序去控制（截图/点击），需要确认状态直接问

## 账号

- 测试账号：`3538285881@qq.com`（昵称 wlt，id 3541），密码用户自己知道
- 之前用过的另一个测试号：`3758143476@qq.com`
