import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var playerService: AudioPlayerService
    @Environment(\.dismiss) private var dismiss

    @State private var showLyrics = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showLyrics {
                    LyricsContentView(
                        lyrics: playerService.currentLyrics,
                        currentPosition: playerService.currentPosition
                    )
                } else {
                    artwork
                }

                trackInfo
                progress
                controls
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .navigationTitle("正在播放")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.backward")
                    }
                    .accessibilityLabel("返回")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showLyrics.toggle()
                    } label: {
                        Image(systemName: showLyrics ? "text.bubble.fill" : "text.bubble")
                    }
                    .accessibilityLabel(showLyrics ? "收起歌词" : "显示歌词")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .accessibilityLabel("收起")
                }
            }
            .overlay(alignment: .leading) {
                edgeSwipeArea
            }
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
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
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
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.top, 20)
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
            .tint(.accentColor)

            HStack {
                Text(formatTime(playerService.currentPosition))
                Spacer()
                Text(formatTime(playerService.duration))
            }
            .font(.caption)
            .monospacedDigit()
            .foregroundStyle(.secondary)
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
                    .foregroundStyle(playerService.isFavorite ? Color.accentColor : Color.primary)
            }
            .accessibilityLabel(playerService.isFavorite ? "取消收藏" : "收藏")
        }
        .buttonStyle(.plain)
        .padding(.top, 28)
    }

    // MARK: - 侧滑返回

    private var edgeSwipeArea: some View {
        Color.clear
            .frame(width: 24)
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

    private var parsedLyrics: [(time: TimeInterval, text: String)] {
        parseLRC(lyrics)
    }

    private var currentIndex: Int {
        let lines = parsedLyrics
        guard !lines.isEmpty else { return -1 }
        var index = -1
        for (i, line) in lines.enumerated() where currentPosition >= line.time {
            index = i
        }
        return index
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
                                .font(isCurrent ? .title3.bold() : .body)
                                .foregroundStyle(isCurrent ? Color.primary : Color.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                                .id(index)
                                .animation(.easeInOut(duration: 0.25), value: isCurrent)
                        }
                    }
                    .padding(.vertical, 140)
                }
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

    private func parseLRC(_ lrc: String) -> [(time: TimeInterval, text: String)] {
        var result: [(TimeInterval, String)] = []
        let lines = lrc.components(separatedBy: "\n")

        for line in lines {
            let pattern = "\\[(\\d{2}):(\\d{2})\\.?(\\d{0,3})\\](.*)$"
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) else {
                continue
            }

            let minStr = String(line[Range(match.range(at: 1), in: line)!])
            let secStr = String(line[Range(match.range(at: 2), in: line)!])
            let msRange = match.range(at: 3)
            let textRange = match.range(at: 4)

            let min = Double(minStr) ?? 0
            let sec = Double(secStr) ?? 0
            var ms: Double = 0
            if msRange.location != NSNotFound, let range = Range(msRange, in: line) {
                let msStr = String(line[range])
                if !msStr.isEmpty {
                    ms = (Double(msStr) ?? 0) / (msStr.count == 2 ? 100 : 1000)
                }
            }

            let time = min * 60 + sec + ms
            var text = ""
            if textRange.location != NSNotFound, let range = Range(textRange, in: line) {
                text = String(line[range]).trimmingCharacters(in: .whitespaces)
            }

            if !text.isEmpty {
                result.append((time, text))
            }
        }

        return result.sorted { $0.0 < $1.0 }
    }
}
