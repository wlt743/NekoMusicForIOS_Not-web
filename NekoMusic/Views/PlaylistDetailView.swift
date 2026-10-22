import SwiftUI

struct PlaylistDetailView: View {
    @EnvironmentObject var playerService: AudioPlayerService
    let playlistId: Int
    let playlistName: String
    
    @State private var musics: [Music] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("加载中...")
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.gray)
                    Text(error)
                        .foregroundColor(.gray)
                    Button("重试") {
                        Task { await loadPlaylistMusic() }
                    }
                    .buttonStyle(.bordered)
                }
            } else if musics.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "music.note")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("歌单暂无音乐")
                        .foregroundColor(.gray)
                }
            } else {
                List {
                    // Header
                    Section {
                        HStack(spacing: 16) {
                            Button {
                                playerService.setPlaylist(musics)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.fill")
                                    Text("播放全部")
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    LinearGradient(
                                        colors: [.pink, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(20)
                            }
                            
                            Text("\(musics.count) 首歌曲")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Music List
                    Section {
                        ForEach(Array(musics.enumerated()), id: \.element.id) { index, music in
                            HStack(spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 24)
                                
                                RemoteImage(url: APIConfig.buildMusicCoverURL(musicId: music.id, coverFilePath: music.coverFilePath)) { image in
                                    image.resizable().aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.gray.opacity(0.2))
                                        .overlay(Image(systemName: "music.note").font(.caption).foregroundColor(.gray))
                                }
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(music.title)
                                        .font(.body)
                                        .lineLimit(1)
                                        .foregroundColor(playerService.currentMusic?.id == music.id ? .pink : .primary)
                                    Text(music.artist)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                if playerService.currentMusic?.id == music.id {
                                    Image(systemName: playerService.isPlaying ? "speaker.wave.2.fill" : "speaker.fill")
                                        .foregroundColor(.pink)
                                        .font(.caption)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                playerService.setPlaylist(musics, startAt: index)
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(playlistName)
        .task {
            await loadPlaylistMusic()
        }
    }
    
    private func loadPlaylistMusic() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response: PlaylistMusicListResponse = try await NetworkService.shared.get(
                url: APIConfig.playlistMusicURL(id: playlistId)
            )
            
            if response.success, let musicList = response.musicList {
                let convertedMusics = musicList.map { pm in
                    Music(
                        id: pm.id,
                        title: pm.title,
                        artist: pm.artist,
                        album: pm.album,
                        duration: pm.duration,
                        filePath: pm.filePath,
                        coverFilePath: pm.coverPath,
                        uploadUserId: nil,
                        createdAt: nil,
                        playCount: nil,
                        lrc: nil
                    )
                }
                await MainActor.run {
                    self.musics = convertedMusics
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.errorMessage = response.message
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}
