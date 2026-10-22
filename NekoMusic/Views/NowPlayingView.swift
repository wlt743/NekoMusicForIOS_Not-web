import SwiftUI

struct NowPlayingView: View {
    @EnvironmentObject var playerService: AudioPlayerService
    @Environment(\.dismiss) private var dismiss
    @State private var showLyrics = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [.pink.opacity(0.3), .purple.opacity(0.3), .black.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Bar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 2) {
                        Text("正在播放")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Button {
                        showLyrics.toggle()
                    } label: {
                        Image(systemName: showLyrics ? "text.bubble.fill" : "text.bubble")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                .padding()
                
                if showLyrics {
                    // Lyrics View
                    LyricsContentView(lyrics: playerService.currentLyrics, currentPosition: playerService.currentPosition)
                        .padding(.horizontal)
                } else {
                    Spacer()
                    
                    // Album Art
                    if let music = playerService.currentMusic {
                        RemoteImage(url: APIConfig.buildMusicCoverURL(musicId: music.id, coverFilePath: music.coverFilePath)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 20)
                                .fill(
                                    LinearGradient(
                                        colors: [.pink.opacity(0.5), .purple.opacity(0.5)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    Image(systemName: "music.note")
                                        .font(.system(size: 60))
                                        .foregroundColor(.white.opacity(0.6))
                                )
                        }
                        .frame(width: 280, height: 280)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                    }
                    
                    Spacer()
                }
                
                // Song Info
                VStack(spacing: 8) {
                    Text(playerService.currentMusic?.title ?? "未知歌曲")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(playerService.currentMusic?.artist ?? "未知歌手")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
                .padding(.horizontal, 32)
                .padding(.top, 20)
                
                // Progress Bar
                VStack(spacing: 8) {
                    Slider(
                        value: Binding(
                            get: { playerService.currentPosition },
                            set: { playerService.seekTo(position: $0) }
                        ),
                        in: 0...max(playerService.duration, 1)
                    )
                    .accentColor(.white)
                    
                    HStack {
                        Text(formatTime(playerService.currentPosition))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Spacer()
                        Text(formatTime(playerService.duration))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 32)
                .padding(.top, 20)
                
                // Controls
                HStack(spacing: 40) {
                    // Play Mode
                    Button {
                        playerService.togglePlayMode()
                    } label: {
                        Image(systemName: playerService.playMode.icon)
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    // Previous
                    Button {
                        playerService.previous()
                    } label: {
                        Image(systemName: "backward.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    
                    // Play/Pause
                    Button {
                        playerService.togglePlayPause()
                    } label: {
                        Image(systemName: playerService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.white)
                    }
                    
                    // Next
                    Button {
                        playerService.next()
                    } label: {
                        Image(systemName: "forward.fill")
                            .font(.title)
                            .foregroundColor(.white)
                    }
                    
                    // Favorite
                    Button {
                        playerService.toggleFavorite()
                    } label: {
                        Image(systemName: playerService.isFavorite ? "heart.fill" : "heart")
                            .font(.title3)
                            .foregroundColor(playerService.isFavorite ? .pink : .white.opacity(0.8))
                    }
                }
                .padding(.top, 32)
                .padding(.bottom, 48)
            }
        }
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let min = Int(seconds) / 60
        let sec = Int(seconds) % 60
        return String(format: "%d:%02d", min, sec)
    }
}

// MARK: - Lyrics Content View
struct LyricsContentView: View {
    let lyrics: String
    let currentPosition: TimeInterval
    
    private var parsedLyrics: [(time: TimeInterval, text: String)] {
        parseLRC(lyrics)
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if lyrics.isEmpty {
                    Text("暂无歌词")
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.top, 60)
                } else {
                    ForEach(Array(parsedLyrics.enumerated()), id: \.offset) { index, line in
                        let isCurrentLine = isCurrentLyricLine(index: index)
                        Text(line.text)
                            .font(isCurrentLine ? .body.bold() : .body)
                            .foregroundColor(isCurrentLine ? .white : .white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 4)
                    }
                }
            }
            .padding(.vertical, 20)
        }
    }
    
    private func isCurrentLyricLine(index: Int) -> Bool {
        guard index < parsedLyrics.count else { return false }
        let currentTime = currentPosition
        let lineTime = parsedLyrics[index].time
        
        if index + 1 < parsedLyrics.count {
            let nextTime = parsedLyrics[index + 1].time
            return currentTime >= lineTime && currentTime < nextTime
        }
        return currentTime >= lineTime
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
