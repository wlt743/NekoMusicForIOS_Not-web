# 更新日志

## 1.0.1 — 2026-10-22

适配 NekoMusic 后端 2026-10 的接口迁移，恢复播放、封面与列表加载。

### 适配后端迁移

- **更换服务端域名**：`music.cnmsb.xin` → `music.nekocore.cn`（旧域名会 308 永久重定向）
- **新增客户端识别**：所有请求携带完整的客户端请求头（`User-Agent`、`X-Neko-Client`、`Sec-Fetch-*` 等），
  避免被服务端判为爬虫而返回 `403`
- **新增请求防重放 nonce**：完整实现「换题 → SHA-256 工作量证明 → 兑换 nonce」流程，
  读写分池、批量领取、过期丢弃、失败退避重试；业务请求遇到 `409` 时自动换 nonce 重试一次
- **音频播放链路改造**：`/api/music/file/{id}` 不再 302 跳转到音频，改为返回 JSON 中的 `data.url`，
  客户端先解析出真实媒体地址再交给 `AVPlayer` 播放
- **歌词获取方式调整**：改为从 `/api/music/info/{id}` 的 `lyrics` 字段读取
- **排行榜 / 最新列表**：适配新接口固定返回条数的行为，移除已废弃的 `limit` 参数

### 适配账号体系

- **登录改为邮箱 + 密码**：请求体由 `username` 改为 `email`，登录页同步改为邮箱输入
- **注册改为昵称 + 邮箱 + 验证码**：请求体使用 `nickname`
- **新增滑块人机验证**：注册发信前先 `GET /api/captcha/slider` 取题，拖动拼图后
  `POST /api/captcha/slider/verify`（提交 `captchaToken`、`captchaOffsetX` 与拖动轨迹 `dragTrace`），
  拿到一次性 `captchaPassToken` 后再调用 `POST /api/user/send-verification`
- **用户字段兼容**：新接口返回 `nickname`，客户端同时兼容旧的 `username` 键，已有登录状态不会被清掉
- 登录后收藏、我的歌单、创建歌单、外部歌单导入恢复可用

### 修复与优化

- 封面与头像改用自定义图片加载器（携带客户端请求头 + 内存缓存），修复替换 `AsyncImage` 后封面无法显示的问题
- 修复切歌时 Combine 订阅不断累积导致的内存增长
- 网络层统一处理 `401` / `409` / `429` / `503`，错误提示优先采用服务端返回的 `message`

## 1.0.0

- 首个版本：首页排行与最新、搜索、歌单、收藏、网易云 / QQ 音乐歌单导入、后台播放与锁屏控制、LRC 歌词。
