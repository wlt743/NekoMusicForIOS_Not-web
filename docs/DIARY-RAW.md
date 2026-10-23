# 手记

# 一行一条，写什么都可以。插件只读，不会覆盖它。

- 给 wlt743（吴丽汀）做 NekoMusic iOS 客户端。SwiftUI 原生，仓库在 /Users/bf/Documents/deepseek-harness/default-workspace/NekoMusicForIOS_Not-web，后端 https://music.nekocore.cn，文档仓库 NekoMusicDocs。
- 交接文档在桌面 ~/Desktop/NekoMusic-交接说明.md，已经写到 643 行、第 17 节。下次接手先读它，别从零摸。
- 真机：iPhone 13，UDID 00008110-001E64C636A2801E，Personal Team B9N6W9S7D8，Bundle com.wlt743.nekomusic，免费签名 7 天过期。
- 后端只认境内 IP：Clash 系统代理一开，全站返回 409「请求已失效」。测试前必须让他关代理，要用 GitHub 再开。
- 部署命令记在交接文档第 16 节：xcodebuild -destination id=... -allowProvisioningUpdates，再 devicectl install。无线调试也能装，拔线不影响。
- 今天补的功能：歌单导入走 /loser SSE（网易云/QQ/酷狗/汽水）、每日推荐、评论、站内消息、VIP 页、上传音乐、主题色+调色盘、首页壁纸、歌词字号、拉黑、分享面板、点歌自动弹播放页。
- 主题色不生效的坑：ContentView / MiniPlayerBar / PlaylistImportView 里的 .tint(.accentColor) 会把根 tint 压回粉色，删掉才全局生效。
- 壁纸不显示的坑：TabView 自带不透明底，全局 ZStack 会被盖住；必须每个主 Tab 自己有背景。深色模式 ultraThinMaterial 会把壁纸压成纯黑，要用 systemBackground 薄纱。
- iOS 26 的 scroll edge effect 会在歌词滚到导航栏下时加色块，toolbarBackground(.hidden) 压不住，最后改成顶部 170pt 向下渐隐的毛玻璃 overlay。
- 分享功能：iOS 没有「指定分享到某个 App」的 API，只能 UIActivityViewController 让用户选；微信直连必须集成 SDK。他最后选了「复制链接 + 打开对应 App」的方案。
- 他的使用习惯：改完要立刻装真机看效果；同一处点击我试两次不中就叫他来点；遇到卡点用问答让他选，别自己硬猜。
- 模型高峰期会掉线，重要状态要随手写进交接文档，别攒着。今天就是因为这个被催着收尾。
- 装过 feiyu-memory 插件，这本账就是它管的；数据在 ~/.dsh/feiyu-diary。
- Live Activity 锁屏歌词折腾了十几轮最后放弃：ContentState 只有 4KB，塞不下封面；App Group 共享文件免费签名不给；系统还节流更新。教训是动手前先查平台硬限制，别先写代码。代码留着，开关关了。
