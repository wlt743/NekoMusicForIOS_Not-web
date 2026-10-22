import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var playerService: AudioPlayerService

    @State private var favorites: [FavoriteMusic] = []
    @State private var showLogin = false
    @State private var showImport = false

    var body: some View {
        NavigationStack {
            Group {
                if !authService.isLoggedIn {
                    EmptyStateView(
                        title: "登录后查看你的音乐库",
                        systemImage: "person.crop.circle",
                        actionTitle: "去登录"
                    ) {
                        showLogin = true
                    }
                } else {
                    List {
                        Section {
                            NavigationLink {
                                FavoritesView()
                            } label: {
                                Label("我的收藏", systemImage: "heart.fill")
                                    .badge(favorites.count)
                            }

                            NavigationLink {
                                PlaylistsView()
                            } label: {
                                Label("我的歌单", systemImage: "music.note.list")
                            }
                        } header: {
                            Text("我的音乐")
                        }

                        Section {
                            Button {
                                showImport = true
                            } label: {
                                Label("导入外部歌单", systemImage: "square.and.arrow.down")
                            }
                        } header: {
                            Text("导入")
                        } footer: {
                            Text("支持从网易云音乐、QQ 音乐导入歌单")
                        }

                        if !playerService.playlist.isEmpty {
                            Section {
                                ForEach(playerService.playlist) { music in
                                    Button {
                                        playerService.playMusic(music)
                                    } label: {
                                        MusicRow(
                                            music: music,
                                            isCurrent: playerService.currentMusic?.id == music.id,
                                            isPlaying: playerService.isPlaying
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            } header: {
                                Text("当前播放列表（\(playerService.playlist.count)）")
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable { await loadFavorites() }
                }
            }
            .navigationTitle("音乐库")
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
        .sheet(isPresented: $showImport) {
            PlaylistImportView()
                .environmentObject(authService)
        }
        .task {
            if authService.isLoggedIn {
                await loadFavorites()
            }
        }
    }

    private func loadFavorites() async {
        guard let token = authService.token else { return }

        do {
            let result = try await FavoriteService.shared.getFavorites(token: token)
            await MainActor.run {
                self.favorites = result
            }
        } catch {
            print("Load favorites error: \(error)")
        }
    }
}

// MARK: - 我的收藏

struct FavoritesView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var playerService: AudioPlayerService

    @State private var favorites: [FavoriteMusic] = []
    @State private var isLoading = true

    private var musics: [Music] {
        favorites.map { fav in
            Music(
                id: fav.id, title: fav.title, artist: fav.artist, album: fav.album,
                duration: fav.duration, filePath: nil, coverFilePath: fav.cover,
                uploadUserId: nil, createdAt: nil, playCount: nil, lrc: nil
            )
        }
    }

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if favorites.isEmpty {
                EmptyStateView(title: "还没有收藏的音乐", systemImage: "heart")
            } else {
                List {
                    Section {
                        Button {
                            playerService.setPlaylist(musics)
                        } label: {
                            Label("播放全部（\(musics.count)）", systemImage: "play.fill")
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
        .navigationTitle("我的收藏")
        .task {
            if favorites.isEmpty {
                await loadFavorites()
            }
        }
    }

    private func loadFavorites() async {
        guard let token = authService.token else {
            isLoading = false
            return
        }

        do {
            let result = try await FavoriteService.shared.getFavorites(token: token)
            await MainActor.run {
                self.favorites = result
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

// MARK: - 我的歌单

struct PlaylistsView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var playerService: AudioPlayerService

    @State private var playlists: [PlaylistInfo] = []
    @State private var isLoading = true
    @State private var showCreateAlert = false
    @State private var newPlaylistName = ""

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if playlists.isEmpty {
                EmptyStateView(
                    title: "还没有创建歌单",
                    systemImage: "music.note.list",
                    actionTitle: "创建歌单"
                ) {
                    showCreateAlert = true
                }
            } else {
                List {
                    ForEach(playlists) { playlist in
                        NavigationLink {
                            PlaylistDetailView(playlistId: playlist.id, playlistName: playlist.name)
                        } label: {
                            Label {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(playlist.name)
                                    Text("\(playlist.musicCount) 首")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            } icon: {
                                Image(systemName: "music.note.list")
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("我的歌单")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateAlert = true
                } label: {
                    Label("创建歌单", systemImage: "plus")
                }
            }
        }
        .alert("创建歌单", isPresented: $showCreateAlert) {
            TextField("歌单名称", text: $newPlaylistName)
            Button("创建") {
                Task { await createPlaylist() }
            }
            Button("取消", role: .cancel) {
                newPlaylistName = ""
            }
        }
        .task {
            if playlists.isEmpty {
                await loadPlaylists()
            }
        }
    }

    private func loadPlaylists() async {
        guard let token = authService.token else {
            isLoading = false
            return
        }

        do {
            let response: PlaylistListResponse = try await NetworkService.shared.get(
                url: APIConfig.myPlaylistsURL(),
                token: token
            )
            await MainActor.run {
                self.playlists = response.playlists ?? []
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }

    private func createPlaylist() async {
        guard let token = authService.token, !newPlaylistName.isEmpty else { return }

        struct CreateRequest: Codable {
            let name: String
        }

        do {
            let _: PlaylistResponse = try await NetworkService.shared.post(
                url: APIConfig.playlistCreateURL(),
                body: CreateRequest(name: newPlaylistName),
                token: token
            )
            newPlaylistName = ""
            await loadPlaylists()
        } catch {
            print("Create playlist error: \(error)")
        }
    }
}
