import SwiftUI

struct PlaylistDetailView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var playerService: AudioPlayerService

    let playlistId: Int
    let playlistName: String

    @State private var detail: PlaylistInfo?
    @State private var musics: [Music] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private var displayName: String {
        detail?.name ?? playlistName
    }

    private var coverURL: String? {
        if let cover = detail?.coverPath, !cover.isEmpty {
            return APIConfig.buildFullURL(path: cover)
        }
        if let cover = detail?.firstMusicCover, !cover.isEmpty {
            return APIConfig.buildFullURL(path: cover)
        }
        if let first = musics.first {
            return APIConfig.buildMusicCoverURL(musicId: first.id, coverFilePath: first.coverFilePath)
        }
        return nil
    }

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
                    systemImage: "music.note",
                    description: detail?.description
                )
            } else {
                List {
                    Section {
                        header
                            .listRowInsets(EdgeInsets(top: 8, leading: Layout.horizontalPadding, bottom: 8, trailing: Layout.horizontalPadding))
                            .listRowBackground(Color.clear)

                        Button {
                            playerService.setPlaylist(musics)
                        } label: {
                            Label("播放全部（\(musics.count) 首）", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .listRowInsets(EdgeInsets(top: 4, leading: Layout.horizontalPadding, bottom: 8, trailing: Layout.horizontalPadding))
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
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await loadPlaylistMusic()
        }
        .task {
            if musics.isEmpty {
                await loadPlaylistMusic()
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            CoverImage(url: coverURL, size: 88, cornerRadius: 10)

            VStack(alignment: .leading, spacing: 6) {
                Text(displayName)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .lineLimit(2)

                if let username = detail?.username, !username.isEmpty {
                    Text(username)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text("\(musics.count) 首")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let description = detail?.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private func loadPlaylistMusic() async {
        isLoading = true
        errorMessage = nil

        // 1. 公开歌单详情（/api/playlist/{id}），失败不阻断曲目列表
        if let response: PlaylistResponse = try? await NetworkService.shared.get(
            url: APIConfig.playlistDetailURL(id: playlistId)
        ) {
            await MainActor.run {
                self.detail = response.playlist
            }
        }

        // 2. 曲目列表
        do {
            let response: PlaylistMusicListResponse = try await NetworkService.shared.get(
                url: APIConfig.playlistMusicURL(id: playlistId),
                token: authService.token
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
