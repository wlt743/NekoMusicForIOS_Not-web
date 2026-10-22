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
                ProgressView("加载中…")
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                EmptyStateView(
                    title: "加载失败",
                    systemImage: "exclamationmark.triangle",
                    description: error,
                    actionTitle: "重试"
                ) {
                    Task { await loadPlaylistMusic() }
                }
            } else if musics.isEmpty {
                EmptyStateView(
                    title: "歌单暂无音乐",
                    systemImage: "music.note"
                )
            } else {
                List {
                    Section {
                        Button {
                            playerService.setPlaylist(musics)
                        } label: {
                            Label("播放全部（\(musics.count) 首）", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .listRowInsets(EdgeInsets(top: 8, leading: Layout.horizontalPadding, bottom: 8, trailing: Layout.horizontalPadding))
                        .listRowBackground(Color.clear)
                    }

                    Section {
                        ForEach(Array(musics.enumerated()), id: \.element.id) { index, music in
                            Button {
                                playerService.setPlaylist(musics, startAt: index)
                            } label: {
                                MusicRow(
                                    music: music,
                                    isCurrent: playerService.currentMusic?.id == music.id,
                                    isPlaying: playerService.isPlaying
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle(playlistName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if musics.isEmpty {
                await loadPlaylistMusic()
            }
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
                let converted = musicList.map { pm in
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
                    self.musics = converted
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
