import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var playerService: AudioPlayerService
    @EnvironmentObject var appearance: AppearanceSettings
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var lyricProgress: CGFloat = 0
    @State private var dragStartProgress: CGFloat = 0
    @State private var isDraggingPage = false
    @State private var showComments = false
    @State private var showBlockConfirm = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GeometryReader { geo in
                    let width = max(geo.size.width, 1)
                    ZStack {
                        coverPage
                            .offset(x: -lyricProgress * width)
                            .allowsHitTesting(lyricProgress < 0.5)

                        lyricsPage
                            .offset(x: (1 - lyricProgress) * width)
                            .allowsHitTesting(lyricProgress > 0.5)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .simultaneousGesture(pageDrag(width: width))
                    .clipped()
                }
                .padding(.horizontal, 24)

                trackInfo
                    .padding(.horizontal, 24)
                progress
                    .padding(.horizontal, 24)
                controls
                    .padding(.horizontal, 24)
            }
            .foregroundStyle(.white)
            .padding(.bottom, 24)
            .background {
                coverBackground
            }
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .mask(
                        LinearGradient(
                            colors: [.black, .black.opacity(0.35), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 170)
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)
            }
            .navigationTitle("正在播放")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.backward")
                    }
                    .tint(.white)
                    .accessibilityLabel("返回")
                }

                if isWideLayout {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: shareText) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .tint(.white)
                        .disabled(playerService.currentMusic == nil)
                        .accessibilityLabel("分享")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showComments = true
                    } label: {
                        Image(systemName: "bubble.left.and.bubble.right")
                    }
                    .tint(.white)
                    .disabled(playerService.currentMusic == nil)
                    .accessibilityLabel("评论")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        toggleLyrics()
                    } label: {
                        Text("词")
                            .font(.system(size: 17, weight: lyricProgress > 0.5 ? .bold : .regular))
                            .foregroundStyle(lyricProgress > 0.5 ? Color.accentColor : Color.white)
                    }
                    .accessibilityLabel(lyricProgress > 0.5 ? "收起歌词" : "显示歌词")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ShareLink(item: shareText) {
                            Label("分享这首歌", systemImage: "square.and.arrow.up")
                        }
                        .disabled(playerService.currentMusic == nil)

                        Button(role: .destructive) {
                            showBlockConfirm = true
                        } label: {
                            Label("拉黑这首歌", systemImage: "hand.raised.slash")
                        }
                        .disabled(playerService.currentMusic == nil)

                        Button {
                            dismiss()
                        } label: {
                            Label("收起播放页", systemImage: "chevron.down")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .tint(.white)
                    .accessibilityLabel("更多")
                }
            }
            .overlay(alignment: .leading) {
                edgeSwipeArea
            }
        }
        .sheet(isPresented: $showComments) {
            if let music = playerService.currentMusic {
                CommentsView(music: music)
            }
        }
        .confirmationDialog("拉黑这首歌？", isPresented: $showBlockConfirm, titleVisibility: .visible) {
            Button("不再播放《\(playerService.currentMusic?.title ?? "")》", role: .destructive) {
                blockCurrent()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("拉黑后这首歌会从推荐、搜索、歌单和收藏里隐藏，并跳过播放。只保存在本机。")
        }
    }

    /// 折叠屏 / iPad 这类宽屏用工具栏分享，直板机放到歌名右侧
    private var isWideLayout: Bool { horizontalSizeClass == .regular }

    private var shareText: String {
        guard let music = playerService.currentMusic else { return APIConfig.baseURL }
        return "《\(music.title)》- \(music.artist)\n\(APIConfig.baseURL)/detail/\(music.id)"
    }

    private func blockCurrent() {
        guard let music = playerService.currentMusic else { return }
        BlacklistService.shared.block(music)
        playerService.next()
    }

    // MARK: - 两页

    private var coverPage: some View {
        artwork
            .onTapGesture { toggleLyrics() }
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("轻点显示歌词")
    }

    private var lyricsPage: some View {
        LyricsContentView(
            lyrics: playerService.currentLyrics,
            currentPosition: playerService.currentPosition,
            fontSize: appearance.lyricFontSize
        )
    }

    // MARK: - 歌词切换

    private func toggleLyrics() {
        let target: CGFloat = lyricProgress > 0.5 ? 0 : 1
        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
            lyricProgress = target
        }
    }

    /// 左滑进歌词、右滑回封面；拖动时实时跟随，松手按位移决定
    private func pageDrag(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                if !isDraggingPage {
                    isDraggingPage = true
                    dragStartProgress = lyricProgress
                }
                let delta = -value.translation.width / width
                lyricProgress = min(1, max(0, dragStartProgress + delta))
            }
            .onEnded { value in
                defer { isDraggingPage = false }
                guard abs(value.translation.width) > abs(value.translation.height) else { return }

                let projected = dragStartProgress - value.predictedEndTranslation.width / width
                withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
                    lyricProgress = projected > 0.5 ? 1 : 0
                }
            }
    }

    // MARK: - 封面模糊背景

    @ViewBuilder
    private var coverBackground: some View {
        if let music = playerService.currentMusic {
            RemoteImage(
                url: APIConfig.buildMusicCoverURL(musicId: music.id, coverFilePath: music.coverFilePath)
            ) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                Color(.systemBackground)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(1.35)
            .blur(radius: 55)
            .overlay(Color.black.opacity(0.52))
            .clipped()
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.35), value: music.id)
        } else {
            Color(.systemBackground)
                .ignoresSafeArea()
        }
    }

    // MARK: - 封面

    @ViewBuilder
    private var artwork: some View {
        Spacer(minLength: 8)

        if let music = playerService.currentMusic {
            RemoteImage(
                url: APIConfig.buildMusicCoverURL(musicId: music.id, coverFilePath: music.coverFilePath)
            ) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Rectangle()
                    .fill(Color(.secondarySystemFill))
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 56))
                            .foregroundStyle(.secondary)
                    }
            }
            .frame(width: 280, height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 24, x: 0, y: 12)
        }

        Spacer(minLength: 8)
    }

    // MARK: - 曲目信息

    private var trackInfo: some View {
        VStack(spacing: 6) {
            Text(playerService.currentMusic?.title ?? "未知歌曲")
                .font(.title2)
                .fontWeight(.bold)
                .lineLimit(1)

            Text(playerService.currentMusic?.artist ?? "未知歌手")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
        .overlay(alignment: .trailing) {
            if !isWideLayout {
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 19))
                        .foregroundStyle(.white)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .disabled(playerService.currentMusic == nil)
                .accessibilityLabel("分享")
            }
        }
    }

    // MARK: - 进度

    private var progress: some View {
        VStack(spacing: 4) {
            Slider(
                value: Binding(
                    get: { playerService.currentPosition },
                    set: { playerService.seekTo(position: $0) }
                ),
                in: 0...max(playerService.duration, 1)
            )
            .tint(.white)

            HStack {
                Text(formatTime(playerService.currentPosition))
                Spacer()
                Text(formatTime(playerService.duration))
            }
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.top, 12)
    }

    // MARK: - 控制

    private var controls: some View {
        HStack(spacing: 36) {
            Button {
                playerService.togglePlayMode()
            } label: {
                Image(systemName: playerService.playMode.icon)
                    .font(.title3)
            }
            .accessibilityLabel(playerService.playMode.displayName)

            Button {
                playerService.previous()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title)
            }
            .accessibilityLabel("上一首")

            Button {
                playerService.togglePlayPause()
            } label: {
                Image(systemName: playerService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
                    .symbolRenderingMode(.hierarchical)
            }
            .accessibilityLabel(playerService.isPlaying ? "暂停" : "播放")

            Button {
                playerService.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title)
            }
            .accessibilityLabel("下一首")

            Button {
                playerService.toggleFavorite()
            } label: {
                Image(systemName: playerService.isFavorite ? "heart.fill" : "heart")
                    .font(.title3)
                    .foregroundStyle(playerService.isFavorite ? Color.accentColor : Color.white)
            }
            .accessibilityLabel(playerService.isFavorite ? "取消收藏" : "收藏")
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .padding(.top, 28)
    }

    // MARK: - 侧滑返回

    private var edgeSwipeArea: some View {
        Color.clear
            .frame(width: 20)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 12)
                    .onEnded { value in
                        if value.translation.width > 60 {
                            dismiss()
                        }
                    }
            )
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let min = Int(seconds) / 60
        let sec = Int(seconds) % 60
        return String(format: "%d:%02d", min, sec)
    }
}

// MARK: - 歌词

struct LyricsContentView: View {
    let lyrics: String
    let currentPosition: TimeInterval
    var fontSize: Double = 19

    private var parsedLyrics: [(time: TimeInterval, text: String)] {
        LyricsParser.parse(lyrics)
    }

    private var currentIndex: Int {
        LyricsParser.index(at: currentPosition, in: parsedLyrics)
    }

    var body: some View {
        if lyrics.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            EmptyStateView(title: "暂无歌词", systemImage: "text.bubble")
        } else {
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 18) {
                        ForEach(Array(parsedLyrics.enumerated()), id: \.offset) { index, line in
                            let isCurrent = index == currentIndex
                            Text(line.text)
                                .font(.system(size: fontSize, weight: .regular))
                                .foregroundStyle(isCurrent ? Color.white : Color.white.opacity(0.38))
                                .shadow(color: .black.opacity(0.5), radius: 8, y: 1)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 5)
                                .id(index)
                                .animation(.easeInOut(duration: 0.25), value: isCurrent)
                        }
                    }
                    .padding(.vertical, 140)
                }
                .modifier(NoTopScrollEdgeEffect())
                .onAppear {
                    scrollToCurrent(proxy, animated: false)
                }
                .onChange(of: currentIndex) { _ in
                    scrollToCurrent(proxy, animated: true)
                }
            }
        }
    }

    private func scrollToCurrent(_ proxy: ScrollViewProxy, animated: Bool) {
        let index = currentIndex
        guard index >= 0, index < parsedLyrics.count else { return }

        if animated {
            withAnimation(.easeInOut(duration: 0.4)) {
                proxy.scrollTo(index, anchor: .center)
            }
        } else {
            proxy.scrollTo(index, anchor: .center)
        }
    }
}


/// iOS 26 的滚动边缘效果会在内容滚到导航栏下方时给 bar 加背景，
/// 播放页是全屏模糊背景，这里关掉顶部效果避免出现色块。
private struct NoTopScrollEdgeEffect: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectStyle(nil, for: .top)
        } else {
            content
        }
    }
}
