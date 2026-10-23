# NekoMusic iOS 项目交接说明（给下一位 AI）

> 最后更新：2026-10-23 03:15（Asia/Shanghai）
> 交接人：上一个 AI（DeepSeek Harness 会话）
> 接收方：下一个接手写代码的 AI

---

## 0. 一句话现状

NekoMusic 的 iOS 原生客户端，SwiftUI，已发版 **2.0.0**（main `7ee4bd0`，tag `v2.0.0`）。
**播放、搜索、封面、账号登录、歌词页可用**；锁屏/控制中心的媒体控制已实现但**未在真机验证**；
灵动岛主动放弃。当前主要工作是继续适配后端、修 UI 细节、验证真机行为。

---

## 1. 仓库与资源

| 用途 | 地址 |
|---|---|
| iOS 主仓库 | https://github.com/wlt743/NekoMusicForIOS_Not-web |
| 后端接口文档 | https://github.com/FantasyNetworkCN/NekoMusicDocs |
| 旧 Flutter/PC 版（可参考功能与接口） | https://github.com/wlt743/NekoMusic_TPOS_ForPC |
| 线上后端 | `https://music.nekocore.cn` |
| 最新 Release | https://github.com/wlt743/NekoMusicForIOS_Not-web/releases/tag/v2.0.0 |

- 主分支：`main`（本地分支 `wip/apple-refactor` 与 main 指向同一提交）
- 当前版本：`MARKETING_VERSION = 2.0.0`，`CURRENT_PROJECT_VERSION = 3`
- Bundle ID：`com.neko.music.ios`
- 最低系统：iOS 16.0（但大量 iOS 26 API 用 `if #available` 包着）
- 依赖：无（无 SPM / CocoaPods）
- LICENSE：AGPL-3.0

本地克隆路径：`/Users/bf/Documents/deepseek-harness/default-workspace/NekoMusicForIOS_Not-web`

---

## 2. 后端接口（最容易踩坑，务必先读）

后端 2026-10 做过一次迁移，旧客户端全部失效。要点如下，详细看 `NekoMusicDocs`。

### 2.1 域名

- `music.cnmsb.xin` → 308 永久重定向到 `music.nekocore.cn`
- 代码里 `APIConfig.baseURL` 已改成新域名

### 2.2 防爬 / 客户端识别

后端会拒绝“不像客户端”的请求，返回 `403` 或降级 HTML。必须带：

```
User-Agent: Mozilla/5.0 ... Chrome/141 ...
X-Neko-Client: ios+2.0.0
Accept: application/json, text/plain, */*
Accept-Language: zh-CN,zh;q=0.9,en;q=0.8
Accept-Encoding: identity        // 关键！带 br 会被判“环境异常”
sec-ch-ua / sec-ch-ua-mobile / sec-ch-ua-platform
Sec-Fetch-Dest / Mode / Site
Referer / Origin
```

- **`Accept-Encoding` 绝对不能是 `gzip, deflate, br`**，会 403「环境异常」
- 换成题接口要求“像浏览器”，纯 `NekoMusic/x` UA 会被拒
- 这些头统一在 `APIConfig.clientHeaders`，`NetworkService` 会给每个请求加上

### 2.3 请求防重放 nonce（PoW）

所有 `/api/*` 除白名单外都要带一次性 `X-Neko-Nonce`：

1. `GET /api/replay/challenge?read=N&write=N` 换题
2. 解 SHA-256 工作量证明：找 `counter` 使 `SHA256(seed + ":" + counter)` 前导零比特 ≥ difficulty
3. `GET /api/replay/nonce?challenge=...&proof=...&read=N&write=N` 兑换
4. 每个 nonce 只能用一次；`GET` 用 read 池，写方法用 write 池
5. `409` 表示 nonce 失效/重放，换一个重试一次

白名单（无需 nonce）：`/api/replay/*`、`/api/music/latest`、`/api/music/ranking`、
`/api/music/cover/*`、`/api/user/avatar/*`、`/media/*`、`/loser/*`（部分）。

实现：`Services/NonceService.swift`（actor，批量 16、40 秒过期、退避重试、后台线程解题）。

⚠️ 注意：短时间内反复换题会被来源加压/限流（`409`/`429`），测试时别刷太猛。

### 2.4 音频播放

`GET /api/music/file/{id}?quality=hq` **不再 302**，改为返回 JSON：

```json
{ "success": true, "data": { "url": "/media/music/43286/43286.mp3" } }
```

需要 nonce。拿到 `data.url` 后再普通 GET（`/media/*` 不需要头和 nonce，支持 Range）。
实现：`MusicService.resolveAudioURL` + `AudioPlayerService.playMusic` 异步解析后播放。

### 2.5 歌词

不再有独立歌词接口，歌词在 `GET /api/music/info/{id}` 的 `data.lyrics`（LRC 字符串）。

### 2.6 账号

- 登录：`POST /api/user/login`，body `{ "email", "password" }`（**不是 username**）
- 注册：`POST /api/user/register`，body `{ "nickname", "password", "email", "verificationCode" }`
- 发送注册验证码前必须完成滑块人机验证：
  1. `GET /api/captcha/slider` 拿 `captchaToken`、背景图、拼图块
  2. `POST /api/captcha/slider/verify`，body `{ captchaToken, captchaOffsetX, dragTrace: [{t,x}] }`
  3. 成功后拿 `captchaPassToken`
  4. `POST /api/user/send-verification`，body `{ email, nickname, captchaPassToken }`
- 用户对象字段是 `nickname`；`UserData` 做了兼容（同时能解 `username`）
- 找回密码 `send-reset-code` / `reset-password` 接口存在，但**UI 还没做入口**

### 2.7 歌单

- `POST /api/playlists/search` 的 `query` **不能为空**，否则 400「搜索关键词不能为空」
- 没有“全部歌单”公开接口，所以「发现页推荐歌单」被改成了搜索优先
- 歌单详情页用的是 `/api/user/playlist/music/{id}`（用户接口），公开歌单应该走 `/api/playlist/{id}`，**待确认**

### 2.8 响应语言

`Accept-Language` 会影响 `message` 文案；错误分支请用 HTTP 状态码与 `success` 判断，不要匹配文案。

---

## 3. 代码结构（26 个 Swift 文件）

```
NekoMusic/
├── NekoMusicApp.swift          入口，注入 AuthService / AudioPlayerService
├── ContentView.swift           TabView + 迷你播放器（iOS 26.1+ 用 tabViewBottomAccessory）
├── Models/
│   ├── Music.swift             Music + fromJSON 手工解析 + 搜索请求体
│   ├── Playlist.swift          歌单 / 收藏 / 歌单曲目 DTO
│   └── User.swift              用户、登录注册、滑块验证 DTO（UserData 兼容 nickname/username）
├── Services/
│   ├── APIConfig.swift         域名、客户端头、nonce 白名单、所有 URL
│   ├── NetworkService.swift    统一请求：加头、注入 nonce、409 重试、错误解码
│   ├── NonceService.swift      换题/解题/兑换 nonce（actor）
│   ├── MusicService.swift      搜索/排行/最新/info/歌词/音频地址解析
│   ├── AuthService.swift       登录注册、滑块、验证码、改密
│   ├── FavoriteService.swift   收藏
│   ├── AudioPlayerService.swift AVPlayer + Now Playing + 远程命令 + 中断处理
│   └── PlaylistImportService.swift 网易云/QQ 歌单抓取 + 批量匹配 + 建歌单
└── Views/
    ├── DesignSystem.swift      统一 Layout、glassSurface、SectionHeader、EmptyStateView、CoverImage、MusicRow
    ├── HomeView.swift          NavigationStack + List + 横向排行卡
    ├── DiscoverView.swift      系统 .searchable，搜索歌曲 + 歌单
    ├── LibraryView.swift       音乐库 / 收藏 / 我的歌单（3 个 struct）
    ├── ProfileView.swift       我的 / 设置 / 关于（3 个 struct）
    ├── LoginView.swift         Form + 邮箱登录 + 注册 + 滑块入口
    ├── SliderCaptchaView.swift 滑块人机验证 UI
    ├── NowPlayingView.swift    播放页 + LyricsContentView（自动跟随滚动）
    ├── LyricsParser.swift      LRC 解析（播放页与系统歌词行共用）
    ├── MiniPlayerBar.swift     MiniPlayerBar（旧系统）+ MiniPlayerAccessory（iOS 26 配件）
    ├── MusicListView.swift     列表页
    ├── PlaylistDetailView.swift 歌单详情
    ├── PlaylistImportView.swift Form 导入页
    └── RemoteImageView.swift   带客户端头的图片加载 + NSCache
```

### 关键设计

- 所有页面用 `NavigationStack`；工具栏用系统 `.toolbar`
- 颜色一律语义色（`.primary` / `.secondary` / `Color(.secondarySystemFill)` / `.tint`），不要写死粉色
- `glassSurface` 在 iOS 26+ 用 `glassEffect`，旧系统回退 `ultraThinMaterial`
- 迷你播放器：
  - iOS 26.1+：`tabViewBottomAccessory(isEnabled: currentMusic != nil)`
  - iOS 26.0：条件渲染的 `tabViewBottomAccessory`
  - 旧系统：`safeAreaInset`
  - 内容：40pt 封面、10 圆角、描边+阴影、底部线性进度条、左右 18pt、上下 7pt

---

## 4. 已经实现的功能

- 首页：热门排行（横向卡片）、最新上架（列表）、下拉刷新、更多
- 搜索：系统 `.searchable`，同时返回歌曲与歌单
- 歌单：详情、播放全部
- 收藏 / 我的歌单 / 创建歌单
- 登录（邮箱）、注册（昵称 + 邮箱 + 滑块 + 验证码）、改密
- 播放器：播放/暂停、上下首、进度、三种播放模式、收藏
- 后台播放、锁屏/控制中心元数据（封面、标题、歌手、时长、进度、队列）
- 扬声器/耳机中断处理
- 歌词页自动跟随滚动、当前行高亮
- 锁屏副标题实时显示当前歌词行
- 外部歌单导入（网易云/QQ，UI 与逻辑都在，但**未端到端验证**）

---

## 5. 已知问题 / 待办（按优先级）

### 高

1. **锁屏 / 控制中心远程按钮未真机验证**
   - `beginReceivingRemoteControlEvents()`、命令 `isEnabled = true`、主线程回调、`skipForward/Backward` 都已写
   - 模拟器无法按锁屏按钮，需要真机确认；若无效，先看 `MPRemoteCommandCenter` 是否收到事件
2. **迷你条点击打开播放页未验证**
   - `MiniPlayerAccessory` 上有 `.onTapGesture { showNowPlaying = true }`
   - 由于合成点击坐标不准，没实测到；如果无效，改成整条 `Button(.plain)`
3. **灵动岛不显示播放态**
   - 系统日志里 MediaRemote 数据齐全（标题/歌手=歌词/封面 768/队列），后台播放正常
   - 但模拟器灵动岛始终只有摄像头开孔。用户已决定放弃，不再投入
4. **外部歌单导入**：`/loser/*` 接口是否要 nonce、是否仍可用，需要用真实歌单验证

### 中

5. **发现页没有“推荐歌单”**：后端拒绝空 query；可考虑固定推荐词（如「热门」）或后端新增接口
6. **歌单详情接口**：疑似应该用 `/api/playlist/{id}` 而不是 `/api/user/playlist/music/{id}`
7. **密码重置 UI 未做**：`send-reset-code` / `reset-password` 接口已接进 `AuthService`
8. **无分页**：列表固定条数（排行 200 / 最新 300）
9. **每日推荐接口未用**：`MusicService.getDailyRecommendations` 存在但无 UI
10. **没有单元测试 / UI 测试**

### 低

11. 迷你条封面/进度条可继续微调（尺寸、间距）
12. 深色模式下的细节未逐页走查
13. iPad 未适配（`NavigationSplitView` 等）

---

## 6. 这一轮发生了什么（时间线）

### 用户做了什么

- 提供两个仓库：iOS 主仓库、后端文档仓库
- 提供线上服务与测试邮箱 `3758143476@qq.com`，并在模拟器上注册/登录成功（昵称 `test`；**密码由用户设置，我未知**）
- 在 DeviceHub 里手动调整 iPhone Duo 的折叠/展开姿态，提供展开态截图
- 提供需求：返回键/侧滑、歌词滚动、系统播放组件、液态玻璃、Duo 适配、迷你条美化
- 开关 Clash 代理（`127.0.0.1:7897`），提供 GitHub PAT（已存 `~/.dsh/.credentials.yaml`）
- 创建/删除了若干模拟器（iPhone 18 Pro、iPhone 14 Pro Max、iPhone Duo）

### 我（上一个 AI）做了什么

1. 克隆仓库、通读全部 Swift 代码与后端文档
2. 后端迁移适配：域名、客户端头、nonce PoW、音频 `data.url`、歌词改 info、排行榜去 limit
3. 账号适配：邮箱登录、昵称注册、滑块验证、用户字段兼容
4. 全量 UI 重构：NavigationStack / List / Form / searchable / ContentUnavailableView / 语义色
5. 液态玻璃：系统组件自动 + `glassSurface` 回退
6. Duo 适配：系统工具栏自动右侧竖排；播放页宽屏右侧返回；不依赖固定尺寸
7. 播放器：补全 Now Playing、进度、队列、封面缓存、中断处理、远程命令
8. 锁屏歌词行：用 `MPMediaItemPropertyArtist` 显示当前歌词
9. 迷你条：三次迭代（玻璃胶囊 → 系统 accessory → 修空状态/高度/对齐/进度条）
10. 发版 1.0.1、2.0.0，写 CHANGELOG、README（海报 + 两台设备截图 + Duo 特色）
11. 打过未签名 IPA 并上传 Release

### 踩过的坑

- `Accept-Encoding: br` → 403「环境异常」
- 纯 NekoMusic UA 换题被拒 → 必须伪装浏览器头
- 音频接口从 302 改成 JSON `data.url`
- 登录从 username 改 email；注册要滑块
- `tabViewBottomAccessory` 在 18 Pro 上会模糊内容（14 Pro Max / 真机未复现）
- 模拟器 `simctl io screenshot` 有时黑屏/旧帧；Duo 展开态必须 `--display <inner-uuid>`
- 这台 Mac 没有 `Simulator.app`，模拟器窗口由 **DeviceHub.app** 提供
- 机器是 8GB M1，两台模拟器同时跑会明显卡；首次启动 App 要 10–20 秒才出画面

---

## 7. 开发环境

| 项 | 值 |
|---|---|
| 机器 | Mac mini，Apple M1，8 GB 内存 |
| Xcode | 27.1（Build 27A9275），iOS 27.1 SDK |
| 模拟器 runtime | iOS 27.0（支持 iPhone 14 Pro Max 等）、iOS 27.1（只支持 iPhone Duo） |
| 模拟器设备 | `NekoMusic iPhone Duo`（iOS 27.1）、`NekoMusic iPhone 14 Pro Max`（iOS 27.0）、用户自建 `iPhone 18 Pro`（iOS 27.0） |
| 模拟器宿主 | `/Applications/Xcode.app/Contents/Applications/DeviceHub.app`（没有 Simulator.app） |
| 代理 | Clash Verge，混合端口 `127.0.0.1:7897`（用户手动开关） |
| git 代理 | 已配置 `http.proxy = https.proxy = http://127.0.0.1:7897` |
| GitHub | 账号 `wlt743`，PAT 在 `~/.dsh/.credentials.yaml` |
| 签名 | **本机无任何签名证书/描述文件**，打不出可安装的签名 IPA |

---

## 8. 常用命令

```bash
cd /Users/bf/Documents/deepseek-harness/default-workspace/NekoMusicForIOS_Not-web

# 类型检查（很快，改完先跑这个）
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
swiftc -typecheck -sdk "$SDK" -target arm64-apple-ios16.0-simulator $(find NekoMusic -name '*.swift')

# 构建模拟器包
xcodebuild -project NekoMusic.xcodeproj -scheme NekoMusic \
  -sdk iphonesimulator -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath build/DerivedData build CODE_SIGNING_ALLOWED=NO

# 安装 / 启动
UDID=$(xcrun simctl list devices | grep 'NekoMusic iPhone Duo' | grep -oE '[0-9A-F-]{36}')
xcrun simctl install "$UDID" build/DerivedData/Build/Products/Debug-iphonesimulator/NekoMusic.app
xcrun simctl launch "$UDID" com.neko.music.ios

# 截图（普通）
xcrun simctl io "$UDID" screenshot /tmp/shot.png

# Duo 展开态（内屏）截图，必须指定 display
xcrun simctl io "$UDID" enumerate   # 找到 2007x2853 的 UUID
xcrun simctl io "$UDID" screenshot --display <UUID> /tmp/duo_inner.png

# 打未签名 IPA
xcodebuild -project NekoMusic.xcodeproj -scheme NekoMusic -sdk iphoneos \
  -configuration Release -derivedDataPath build/DeviceData2 \
  build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
mkdir -p build/ipa/Payload && cp -R build/DeviceData2/Build/Products/Release-iphoneos/NekoMusic.app build/ipa/Payload/
cd build/ipa && zip -qry NekoMusic-2.0.0-unsigned.ipa Payload
```

### 新增 Swift 文件

工程用的是**手动登记的 `PBXFileReference` / `PBXBuildFile`**（ID 形如 `B10000xx` / `B20000xx`），
不是 Xcode 16 的同步文件夹。**新文件必须同时改 `project.pbxproj` 四处**（BuildFile、FileReference、Group children、Sources phase），
否则不参与编译。参考现有 ID 顺延即可。

---

## 9. 测试注意事项

- 首次启动 App 出画面很慢（10–20 秒），别急着判定空白/黑屏
- `simctl io screenshot` 可能返回黑屏或旧帧，优先用 DeviceHub 窗口截图（`screencapture -l <windowid>`）
- Duo 展开后默认截图是黑屏，必须用 `--display` 指定内屏
- 想要自动播放测 UI，可临时在 `ContentView.onAppear` 加 `-play` 启动参数钩子
  （历史上加过多次，**测完必须删掉**，不要留在正式提交里）
- 合成点击（CGEvent）坐标需要按窗口 bounds 换算，容易点偏；重要交互尽量让用户手点
- 不要同时开两台模拟器做重活（8GB 内存）

---

## 10. 发布流程（目前的做法）

1. 改 `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` / `APIConfig.clientVersion`
2. 更新 `CHANGELOG.md`
3. `git commit` + 推 `main`
4. 打 tag 并推送
5. 用 GitHub API 建 Release（body **只放更新内容**，不要放项目介绍/宣传语）
6. 打未签名 IPA，用 uploads API 上传到 Release

⚠️ **Release 正文只写“这版改了什么”**。项目介绍、亮点、宣传语放 README，不要混进发行日志（已犯过一次）。

---

## 11. 需要用户确认 / 下一步建议

1. 真机验证：锁屏/控制中心按钮、锁屏歌词行、进度条
2. 迷你条点击进播放页是否生效
3. 发现页是否要“固定推荐词”入口
4. 歌单详情是否切到 `/api/playlist/{id}`
5. 密码重置 UI 是否要做
6. 仓库 About 描述是否要改（现在是 `nekomusic for ios not web (自己打包签名)`）
7. 是否继续走未签名 IPA，还是搞企业/开发证书

---

## 12. 给下一个 AI 的建议工作方式

- 先读 `NekoMusicDocs` 的 `README.md`、`API-防爬与客户端识别.md`、`API-请求防重放.md`
- 改 UI 前先看 `DesignSystem.swift`，不要重新发明颜色和卡片
- 改网络前先看 `NetworkService.send` 与 `APIConfig.requiresNonce`
- 每次改完先 `swiftc -typecheck`，再 `xcodebuild`
- 测试优先用 Duo（用户主力），直板机按需开
- 不要擅自把项目介绍写进 Release；不要留调试钩子；不要提交 `build/`

---

## 13. 第二轮更新（2026-10-23 凌晨）

### 新增功能

| 功能 | 位置 |
|---|---|
| 外部歌单导入重写为服务端 SSE | `Services/PlaylistImportService.swift`、`Views/PlaylistImportView.swift` |
| 每日推荐 | `HomeView` 首屏 + `MusicService.getDailyRecommendations` |
| 歌单详情改用公开接口 | `PlaylistDetailView` + `/api/playlist/{id}`，含封面/作者/简介头部 |
| 忘记密码 | `LoginView` 入口 + `ForgotPasswordView` |
| 歌曲评论 | `Services/CommentService.swift`、`Views/CommentsView.swift`，播放页工具栏进入 |
| 站内消息 | `Services/NotificationService.swift`、`Views/NotificationsView.swift`，我的页红点 |
| 修改昵称 | `NicknameEditView`（设置 › 账户） |
| 上传头像 | 设置 › 账户 › 更换头像（PhotosPicker + multipart，512px 压缩） |
| 会员中心 | `Views/VipView.swift`，套餐展示 + 下单跳转支付页 |

### 导入接口的现状（重要）

旧实现是「客户端自己搜索匹配 → 建歌单 → 批量加歌」，**已淘汰**。现在是：

1. 客户端只发一个请求：`GET /loser/{netease|qq|kugou|qishui}/pull?...`
2. 后端完成站外匹配、下载入库、加入站内歌单，用 **SSE** 推进度
3. 事件：`start` / `track` / `progress` / `done` / `error`
4. 参数：`playlistId`(网易云) / `disstid`(QQ) / `listid`(酷狗) / `playlist_id`(汽水)，
   加 `targetPlaylistId` 或 `targetPlaylistName` 二选一，`Authorization: <token>`
5. 酷狗、汽水的链接格式很多，客户端**原样传**，由后端解析

**已用真实请求验证过事件格式**，解析逻辑与后端一致。

### 新踩的坑（务必记住）

- ⚠️ **Clash 代理会让后端判定「环境异常」/ 409**。代理出口是 HK，后端只接受境内 IP。
  现象：App 里所有请求「请求已失效，请刷新后重试」，但 `curl` 手动测全部正常
  —— 因为 curl 不走系统代理，App（URLSession）走。
  **测试前让用户关掉 Clash 的系统代理和 TUN**；需要 GitHub 时再让用户打开。
- `/loser/*` 的错误文案在 `msg` 字段而不是 `message`，`NetworkService.message` 已兼容。
- 网易云歌单 `playlistId=1` 是真实大歌单（158 首），别当无效 ID 测试。
- 用 `screencapture -l <windowid>` 绕过窗口遮挡；`System Events` 改过窗口位置后
  **上屏坐标会变**，每次点击前重新取 `CGWindowBounds`。

### 测试账号

- 邮箱 `3758143476@qq.com`，密码 `88888888`，昵称 `test`（id 3541）
- 模拟器登录态是直接把 token 写进 App 的 `Library/Preferences/com.neko.music.ios.plist`
  （键 `auth_token` / `auth_user`）注入的，必须先 terminate App 再启动才生效

### 修复的坑（本轮）

- **「创建歌单」失败时静默**：`catch` 里只有 `print`，用户看到的是“点了没反应”。
  现在会弹「操作失败」提示，创建过程有 loading 遮罩。
- **409 文案太模糊**：`NetworkService` 现在把重试后仍 409 统一转成
  「请求被服务端拒绝，请关闭代理 / VPN 后重试」，比后端的「请求已失效」更可操作。

### 仍未做

- 站内消息的 SSE 实时通道（`/api/user/notifications/stream`，目前用列表接口兜底）
- 扫码登录、听歌识曲、分享视频渲染、用户上传音乐（成本较高，暂缓）
- 导入页「开始导入」按钮的合成点击在缩放窗口下点不中，**待用户手动点一次做端到端验证**
- 头像上传只做了代码，未在模拟器实际跑过（PhotosPicker 需要相册里有图）


---

## 14. 当前状态（2026-10-23 04:30 收尾）

### 代码

- 本轮全部改动已 **本地提交**：`6a3f773`（在 `wip/apple-refactor`，与 main 同一历史）
- **尚未 push 到 GitHub**（需要先让用户打开梯子）
- `swiftc -typecheck` 通过，`xcodebuild` 通过，App 已装进 `iPhone 18 Pro` 模拟器并运行
- 新增 7 个 Swift 文件，全部已在 `project.pbxproj` 登记（ID `B1000030`–`B1000036` / `B2000030`–`B2000036`）

### 已实测通过

- 注入登录态后首页每日推荐正常渲染
- 评论：列表、发表、删除（真实后端往返，测试评论已清理）
- 站内消息：接口字段与模型一致，红点数量正确
- 创建歌单：修复后可正常创建
- 会员中心：4 档套餐、折合日均价计算正确

### 未实测（下一位从这里开始）

1. **外部歌单导入端到端**：SSE 事件格式已用 curl 验证过，但 App 里「开始导入」按钮
   在缩放窗口下合成点击点不中，需要人手点一次
2. **上传头像**：代码完成，模拟器相册没图，未跑过
3. **上传音乐**：代码完成，页面未截图验证
4. **消息中心列表页**：点击「消息」两次没进去，未看到列表 UI

### 已知限制

- `/api/user/notifications/stream` 经 CDN 后**建立连接但不返回任何数据**（curl 也一样），
  `NotificationService.realtimeStreamEnabled` 已设为 `false`，靠列表接口兜底
- 扫码登录在 iOS 端只能做「扫一扫确认」，需要相机；模拟器无摄像头，未实现
- 听歌识曲、分享视频渲染、用户上传音乐管理页未做

### 环境提醒

- 测试前务必关闭 Clash 系统代理（否则全站 409）
- 需要 push / 访问 GitHub 时再打开
- 模拟器窗口用 `System Events` 改过位置后坐标会变，点击前重新取 `CGWindowBounds`


---

## 15. 真机（2026-10-23 中午）

### 已确认可用

- 设备：**iPhone 13**，iOS 27.2 (24B5089g)，UDID `00008110-001E64C636A2801E`
- macOS 27.2 + Xcode 27.1，USB 识别、配对（`paired`）、CoreDevice 隧道均正常
- `xcrun xctrace list devices` 能看到真机；`xcrun devicectl list devices` 显示 `available (paired)`
- 之前的「需要软件更新才能连接」弹窗是 macOS 在装 **Mobile Device Support**，装完自动消失，不用管

### 签名现状（关键）

- `security find-identity -v -p codesigning` → **0 valid identities**，本机没有任何签名证书
- 工程里 `DEVELOPMENT_TEAM = 8L5RMA2CJS` 是**原作者的 Team**，`xcodebuild` 会直接报
  `No Account for Team "8L5RMA2CJS"`
- 免费方案：Xcode → Settings → **Apple Accounts** 登录 Apple ID（账号 `3538288581@qq.com`，
  显示名「吴丽汀」），登录后 Xcode 会自动生成 `Apple Development` 证书
- ⚠️ 注意：账号出现在列表里**不等于已登录**——右侧还有 `Sign In...` 按钮就说明没认证，
  必须点进去输密码（可能需要 2FA）

### 登录后的操作顺序

1. 读 Team ID：`defaults read com.apple.dt.Xcode IDEProvisioningTeams`
2. 替换工程里的 `DEVELOPMENT_TEAM`
3. Bundle ID 要改，`com.neko.music.ios` 属于原开发者，个人免费账号无法注册；
   建议改成 `com.<你的名字>.nekomusic` 之类
4. `xcodebuild -destination 'id=<UDID>' -allowProvisioningUpdates build`
5. `xcrun devicectl device install app --device <UDID> <app 路径>`

### 注意

- 免费签名 **7 天过期**，到期需要重新构建安装
- 首次安装后，手机上要去「设置 → 通用 → VPN 与设备管理」信任开发者证书
- 换 Bundle ID 后模拟器上会变成另一个 App，原来的登录态不会沿用


---

## 16. 真机部署已成功（2026-10-23 12:25）

iPhone 13 上 `com.wlt743.nekomusic` 已安装并正常运行。

### 关键参数

| 项 | 值 |
|---|---|
| 设备 | iPhone 13，iOS 27.2，UDID `00008110-001E64C636A2801E` |
| Apple ID | `3538285881@qq.com`（显示名「吴丽汀」） |
| **Team ID** | **`B9N6W9S7D8`**（Personal Team） |
| Bundle ID | `com.wlt743.nekomusic` |
| 签名方式 | 免费个人签名，**7 天过期** |

⚠️ 注意：证书 subject 里的 `5Z9HY258YG` 是 **OU，不是 Team ID**。装错会报
`No Account for Team "..."`。Team ID 要从 `defaults read com.apple.dt.Xcode IDEProvisioningTeamByIdentifier`
里读 `teamID` 字段。

### 踩过的坑：证书链断裂

现象：`security find-identity -p codesigning` 能列出身份，但 `-v` 显示 0 valid，
`codesign` 报 `unable to build chain to self-signed root`。

原因：开发证书由 **WWDR G3** 签发，而本机系统钥匙串里只有旧版 WWDR，缺 G3 中间证书。

修复（已做，换机器可复用）：

```bash
curl -sL -A "Mozilla/5.0" -o /tmp/wwdrg3.cer \
  https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer
security import /tmp/wwdrg3.cer -k ~/Library/Keychains/login.keychain-db
```

> 不带浏览器 UA 会下载到 HTML 页面，注意用 `file` 检查是不是 "Certificate"。

首次签名会弹钥匙串授权，要输 **Mac 登录密码**并点「始终允许」。

### 部署命令

```bash
cd /Users/bf/Documents/deepseek-harness/default-workspace/NekoMusicForIOS_Not-web
xcodebuild -project NekoMusic.xcodeproj -scheme NekoMusic -configuration Debug \
  -destination 'id=00008110-001E64C636A2801E' -derivedDataPath build/DeviceData \
  -allowProvisioningUpdates build

xcrun devicectl device install app --device 00008110-001E64C636A2801E \
  build/DeviceData/Build/Products/Debug-iphoneos/NekoMusic.app

xcrun devicectl device process launch --device 00008110-001E64C636A2801E com.wlt743.nekomusic
```

真机截图（只读，不要用来控制手机）：

```bash
xcrun devicectl device capture screenshot --device <UDID> --destination /tmp/x.png
```

### 首次安装后必须做

手机「设置 → 通用 → VPN 与设备管理 → 开发者 App → 信任 Apple Development」，
否则启动会报 `profile has not been explicitly trusted by the user`。

### 注意

- 改了 Bundle ID，模拟器上的老 App（`com.neko.music.ios`）是另一份，登录态不共享
- **不要用程序去控制用户手机**（用户明确要求），需要确认运行时直接问


---

## 17. 第三轮更新（2026-10-23 下午 · 播放页与外观）

### 本轮新增功能

| 功能 | 说明 |
|---|---|
| 点歌自动弹播放页 | `AudioPlayerService.setPlaylist` 会置 `presentNowPlaying = true`，`ContentView` 监听后展开 `fullScreenCover`，解决“点了没反应” |
| 播放页封面模糊背景 | 取当前封面高斯模糊 + 52% 黑遮罩，顶部 170pt 向下渐隐的毛玻璃；文字/进度条/按钮统一白色 |
| 歌词切换「词」按钮 | 工具栏气泡图标改为文字「词」，激活时加粗 + 主题色 |
| 歌词跟手分页 | 左滑进歌词、右滑回封面；拖动时 `lyricProgress` 实时跟随，松手按 `predictedEndTranslation` 决定翻页/回弹；点封面也可进 |
| 歌词字号 | 外观里可调 14–28pt，默认 19 |
| 主题色 | 7 个预设 + ColorPicker 调色盘自定义（十六进制存储），即时全局生效 |
| 首页壁纸 | 相册选图，长边压到 2000px 存 Documents；可调**模糊 0–30**、**遮罩 0–90%** |
| 全 Tab 壁纸 | 首页 / 发现 / 音乐库 / 我的 都铺壁纸，子页面保持系统背景 |
| 半透明卡片 | 我的 / 音乐库 / 发现的列表卡片改为 62% 不透明度，与壁纸融合 |
| 歌曲拉黑 | 播放页三点菜单 → 拉黑，本地黑名单，过滤首页/搜索/歌单/收藏，并跳到下一首 |
| 分享面板 | 微信 / QQ / X / 复制链接 / 更多；前三个=复制文案+打开对应 App，「更多」调系统 `UIActivityViewController`；图标从 iTunes Lookup API 拉官方图并缓存 |
| 直板机分享位置 | 宽屏（折叠屏/iPad）放工具栏，直板机放歌名右侧（`horizontalSizeClass` 判断） |

### 关键实现位置

- `Services/AudioPlayerService.swift`：`presentNowPlaying`
- `Views/NowPlayingView.swift`：模糊背景、跟手分页、三点菜单、分享入口
- `Services/AppearanceSettings.swift`：主题色、调色盘、壁纸、模糊/遮罩、歌词字号
- `Views/AppearanceView.swift`：外观设置 UI
- `Views/DesignSystem.swift`：`WallpaperBackdrop`、`NekoDate`
- `Services/BlacklistService.swift` + `Views/BlacklistView.swift`
- `Views/SharePanelView.swift`：自定义分享面板 + `AppIconLoader`

### 本轮踩的坑（重要）

1. **`.tint(.accentColor)` 会覆盖根部主题色**。`ContentView`、`MiniPlayerBar`、`PlaylistImportView` 里都有，删掉后主题色才会全局生效。
2. **iOS 26 的 scroll edge effect**：歌词滚到导航栏下时系统自动加背景色块；`scrollEdgeEffectStyle(nil, for: .top)` 在部分场景压不住，最终改成「导航栏透明 + 顶部一条向下渐隐的毛玻璃 overlay」。
3. **`TabView` 自带不透明底色**，把壁纸放在它下面的全局 `ZStack` 会被整个盖住——必须每个主页面自己 `.background { WallpaperBackdrop() }`。
4. **深色模式下 `.ultraThinMaterial` 几乎全黑**，会把壁纸压成纯黑；改用 `Color(.systemBackground).opacity(dim)` 薄纱。
5. **`canOpenURL` 依赖 Info.plist 的 `LSApplicationQueriesSchemes`**，漏了 `mqq` 就永远判定“没装 QQ”。当前已声明 `alipay / weixin / mqq / mqqapi / twitter`。
6. **分享到微信无法跳过系统面板**：Apple 没有“指定分享目标”的 API，只能 `UIActivityViewController` 由用户选；要直连必须集成微信 SDK。
7. **真机是无线调试**：`Transport Type: localNetwork`，拔掉数据线也能 `devicectl install`。

### 提交记录（本轮）

```
07c27e5 revert(share): 渠道按钮恢复为复制链接并打开对应 App
675c572 fix(share): 渠道按钮统一走系统分享面板
ee61e3a feat(share): 增加 X（Twitter）分享渠道
b6c171c fix(share): 不透明面板背景、修复 QQ 检测、真实 App 图标
612bf1c feat(share): 自定义分享面板
eab4bf4 style(player): 直板机分享按钮移到歌名右侧
531e922 feat(player): 分享按钮
26ad20d style(player): 收起按钮改为三点菜单
26635ad feat: 歌曲拉黑（本地黑名单）
d3b7d7f feat(player): 封面与歌词之间改为带方向的卡片推拉转场
db01ea0 feat(appearance): 壁纸支持调节模糊度与遮罩强度
aa45113 fix(appearance): 壁纸改为每页独立背景
64bdbe2 fix(appearance): 深色模式下壁纸不再被材质压黑
8323173 feat(appearance): 壁纸提升为全局背景
891fe01 style(appearance): 移除多余 Divider 行
0ccb6ce style(appearance): 主题色网格与调色盘合并
9a3140a feat(theme): 主题色支持调色盘自定义
1f47816 fix(theme): 移除各处 .tint(.accentColor) 覆盖
```

### 仍未做

- 微信/QQ 一键直达分享（需 SDK + AppID + 审核）
- 分享视频渲染（`POST /api/video/render/create`，异步发邮件，非 VIP 限 15 秒带水印）
- 歌词页顶部渐变在各机型的一致性
- 卡片透明度目前写死 62%，未做成可调
- 扫码登录、听歌识曲、用户上传音乐管理


---

## 18. Live Activity（锁屏歌词）尝试与放弃（2026-10-23 傍晚）

### 结论：已关闭，代码保留

`LyricLiveActivityManager.isEnabled = false`。Widget Extension（`NekoMusicWidgetExtension`）仍在工程里，但不创建活动。

锁屏现在只有：系统音乐卡（封面/歌名/进度/15 秒）+ `artist` 字段里的一行歌词。

### 试过什么

| 方案 | 结果 |
|---|---|
| ActivityKit + Widget Extension，锁屏三行歌词 | 能跑，但歌词更新不及时 |
| 把封面塞进 `ContentState.artworkData` | **封面永远不显示** |
| 缩小封面到 48px / 质量 0.5 | 仍然不显示 |
| 活动创建改为同步（原来是异步 Task） | 歌词能滚了，封面还是不行 |

### 真正的硬限制（查文档 + 实测确认）

1. **`ContentState` 有 4KB 上限**（[参考](https://github.com/perminder-klair/subwave/pull/1489/files#2)），图片转 Data 必然超；Apple 推荐把图片放 **App Group 共享容器**，Widget 读文件。
2. **App Group 需要付费开发者账号**，免费个人签名不支持 → 这条路断了。
3. **Live Activity 更新被系统节流**，密集更新会被合并/丢弃，快速歌词必然卡。
4. `Activity.request` 放在 `Task {}` 里会被延迟十几秒执行，期间所有 `update` 因 `activity == nil` 静默丢弃 —— 这个坑很隐蔽，日志里表现为「卡片永远停在初始文案」。

### 如果以后还要做

- 需要：付费账号（App Group）、服务端 push 更新（`Activity.pushType = .token`）、或者接受「只显示一句、不追求逐句同步」
- 另一个坑：新增 Widget Extension 后，真机首次启动会因签名变化要求**重新信任开发者证书**

---

## 19. 当前功能盘点（2026-10-23 傍晚）

### 已实现

| 模块 | 状态 |
|---|---|
| 登录 / 注册 / 滑块人机验证 | ✅ |
| 忘记密码（发码 + 重置） | ✅ |
| 修改密码 / 修改昵称 / 上传头像 | ✅ |
| 每日推荐 | ✅ |
| 搜索（音乐 + 歌单） | ✅ |
| 播放（音频 URL 解析、歌词、进度、倍速？） | ✅ 无倍速 |
| 收藏（音乐） | ✅ |
| 歌单：创建 / 删除 / 详情 / 加歌 / 移除 | ✅（改名/描述未做） |
| 外部歌单导入（网易云/QQ/酷狗/汽水，SSE） | ✅ |
| 歌曲评论（列表/回复/发表/删除） | ✅ |
| 站内消息（列表/分页/已读/红点） | ✅（SSE 实时通道未接通） |
| VIP 价目 + 下单跳转 | ✅（支付靠外部 App） |
| 上传音乐（审核） | ✅（上传列表没做） |
| 歌曲拉黑（本地） | ✅ |
| 分享（系统面板 / 复制+打开 App） | ✅ |
| 主题色（预设 + 调色盘）、首页壁纸、歌词字号 | ✅ |
| 锁屏 / 控制中心控制 + 一行歌词 | ✅（真机验证过） |
| App 图标 | ✅ |

### 未实现（文档里有，代码里没有）

| 功能 | 接口 | 备注 |
|---|---|---|
| 扫码登录 | `/api/user/qrlogin/*` | 手机端只能做「扫一扫确认」，需相机；模拟器测不了 |
| 收藏歌单 | `/api/user/favorite/playlist/*` | 文档第 10–13 节，整套没做 |
| 歌单改名 / 改描述 | `POST /api/user/playlist/update` | |
| 听歌识曲 | 文档「听歌识曲」 | 需要录音 + 音频指纹，成本高 |
| 分享视频渲染 | `/api/video/render/*` | 异步 + 邮件，非 VIP 限 15 秒带水印 |
| 上传音乐列表 / 审核状态 | `/api/user/uploads*` | 上传后看不到自己的列表 |
| 站内消息 SSE 实时通道 | `/api/user/notifications/stream` | 端点经 CDN 不返回数据，已放弃 |
| 播放倍速 | — | 文档没提，用户也没要求 |

---

## 20. 2026-10-23 晚：横屏适配、功能补齐、版本 3.5.0

### 播放页横屏

用户要的效果：**左栏「封面 + 歌名/歌手 + 进度 + 控制」，右栏纯歌词**。

踩过的坑（按顺序）：

1. `fullScreenCover` 里旋转后 `GeometryReader` 拿到的仍是竖屏尺寸（实测 `340×776`），横屏布局完全错乱
2. 改成普通 `ZStack` 图层后尺寸变成 `0×0`（内部 `GeometryReader` 没有外部约束）
3. 最终解法：`ContentView` 用 `GeometryReader` 包住播放页，**显式传 `containerSize`**，播放页不再依赖内部 GeometryReader
4. 封面组件复用竖屏的 `artwork`（内含 `Spacer`），在固定 frame 的 HStack 里会把布局带偏 → 横屏单独写 `landscapeCover`
5. 控件高度超限 → 用 `ViewThatFits` 五档降级（封面 200/170/140/110/84）

### 自适应架构（为折叠屏与 iPad 准备）

```swift
enum PlayerLayoutMode { case portrait, landscape, wide }

layoutMode:
  horizontalSizeClass == .regular  → .wide      // iPad / 折叠屏展开
  verticalSizeClass  == .compact   → .landscape // iPhone 横屏
  其余                              → .portrait
```

- 布局族由 **size class** 决定，不再手算宽高比
- 每个族内部用 **`ViewThatFits`** 决定完整版还是紧凑版
- `wideLayout` 已预置，折叠屏展开与 iPad 会自动进入
- 后续可迁移到 `containerRelativeFrame`（iOS 17+），替代 `height * 0.36` 这类比例常数

### 新增功能

| 功能 | 接口 | 位置 |
|---|---|---|
| 收藏歌单 | `/api/user/favorite-playlists`（GET/POST/DELETE） | 我的 → 收藏歌单；歌单详情书签按钮 |
| 歌单改名/改描述 | `POST /api/user/playlist/update` | 歌单详情铅笔按钮（仅自己的歌单） |
| 我的歌单删除 | `POST /api/user/playlist/delete` | 我的歌单左滑删除（带确认） |
| 我上传的音乐 | `GET /api/user/uploaded-music` | 我的 → 我上传的音乐 |
| 扫码登录 | `POST /api/user/qrlogin/scan`、`/confirm` | 我的 → 扫码登录（给电脑用） |

### 版本

- `MARKETING_VERSION` 由 `3.0.0` → `3.5.0`（主 App 与 Widget Extension 共 4 处）
- GitHub Release：`v3.0.0` 正式、`v3.5.0-beta` 预发布

### 放弃的功能

Live Activity（锁屏多行歌词）已关闭 `isEnabled = false`，原因见第 18 节：ContentState 4KB 上限、App Group 需要付费账号、系统节流。
