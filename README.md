# NekoMusic iOS

一款简洁优雅的 iOS 音乐播放器，使用 SwiftUI 构建。

## 项目地址

- iOS: [bilibiliyouyouou/NekoMusicForIOS_Not-web](https://github.com/bilibiliyouyouou/NekoMusicForIOS_Not-web)
- Android: [FantasyNetworkCN/NekoMusicForAndroid](https://github.com/FantasyNetworkCN/NekoMusicForAndroid)
- PC: [FantasyNetworkCN/NekoMusicForPc](https://github.com/FantasyNetworkCN/NekoMusicForPc)
- Web: [https://music.cnmsb.xin](https://music.cnmsb.xin)

## 功能

- 🎵 音乐搜索、排行榜、最新上架
- ❤️ 收藏管理
- 📋 歌单浏览与播放
- 🎶 完整播放控制（播放/暂停、上一曲/下一曲）
- 🔁 多种播放模式（列表循环、单曲循环、随机播放）
- 📝 歌词显示
- 🔒 用户登录/注册
- 🎛️ 锁屏/控制中心播放控制
- 🖼️ 锁屏封面显示

## 技术栈

- **UI 框架**: SwiftUI
- **最低支持**: iOS 16.0
- **音频播放**: AVFoundation + MediaPlayer
- **网络请求**: URLSession (原生)
- **图片加载**: AsyncImage (原生)
- **架构模式**: MVVM + Service Layer

## 项目结构

```
NekoMusic/
├── NekoMusicApp.swift          # App 入口
├── ContentView.swift           # 主视图 (TabView)
├── Info.plist                  # 应用配置
├── Assets.xcassets/            # 资源文件
├── Models/                     # 数据模型
│   ├── Music.swift
│   ├── User.swift
│   └── Playlist.swift
├── Services/                   # 服务层
│   ├── APIConfig.swift         # API 配置
│   ├── NetworkService.swift    # 网络请求
│   ├── MusicService.swift      # 音乐 API
│   ├── AuthService.swift       # 认证服务
│   ├── FavoriteService.swift   # 收藏服务
│   └── AudioPlayerService.swift # 音频播放
└── Views/                      # 视图
    ├── HomeView.swift          # 首页
    ├── DiscoverView.swift      # 发现（搜索 + 歌单推荐）
    ├── LibraryView.swift       # 音乐库
    ├── ProfileView.swift       # 个人中心
    ├── NowPlayingView.swift    # 正在播放（全屏）
    ├── MiniPlayerBar.swift     # 迷你播放条
    ├── LoginView.swift         # 登录/注册
    ├── MusicListView.swift     # 音乐列表
    └── PlaylistDetailView.swift # 歌单详情
```

## 构建

1. 使用 Xcode 15+ 打开 `NekoMusic.xcodeproj`
2. 选择目标设备（iPhone 模拟器或真机）
3. 点击 Run (⌘R)

## API

后端 API 地址: `https://music.cnmsb.xin`

## 许可证

本项目基于 [GNU Affero General Public License v3.0](LICENSE) 开源。
