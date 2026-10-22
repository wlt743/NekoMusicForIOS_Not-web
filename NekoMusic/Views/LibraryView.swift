import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var playerService: AudioPlayerService
    @State private var favorites: [FavoriteMusic] = []
    @State private var isLoading = false
    @State private var showLoginAlert = false
    @State private var showImportSheet = false
    
    var body: some View {
        NavigationView {
            Group {
                if !authService.isLoggedIn {
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 64))
                            .foregroundColor(.gray)
                        Text("登录后查看你的音乐库")
                            .foregroundColor(.gray)
                        Button("去登录") {
                            showLoginAlert = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.pink)
                    }
                } else {
                    List {
                        // Favorites Section
                        Section {
                            NavigationLink {
                                FavoritesView()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "heart.fill")
                                        .foregroundColor(.pink)
                                        .frame(width: 32)
                                    Text("我的收藏")
                                    Spacer()
                                    Text("\(favorites.count)")
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            NavigationLink {
                                PlaylistsView()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "music.note.list")
                                        .foregroundColor(.purple)
                                        .frame(width: 32)
                                    Text("我的歌单")
                                }
                            }
                        } header: {
                            Text("我的音乐")
                        }
                        
                        // Import Section
                        Section {
                            Button {
                                showImportSheet = true
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "square.and.arrow.down")
                                        .foregroundColor(.orange)
                                        .frame(width: 32)
                                    Text("导入外部歌单")
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .foregroundColor(.primary)
                        } header: {
                            Text("导入")
                        } footer: {
                            Text("支持从网易云音乐、QQ音乐导入歌单")
                        }
                        
                        // Current Playlist
                        if !playerService.playlist.isEmpty {
                            Section {
                                ForEach(playerService.playlist) { music in
                                    MusicRowView(music: music)
                                        .listRowInsets(EdgeInsets())
                                        .onTapGesture {
                                            playerService.playMusic(music)
                                        }
                                }
                            } header: {
                                Text("当前播放列表 (\(playerService.playlist.count))")
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable {
                        await loadFavorites()
                    }
                }
            }
            .navigationTitle("音乐库")
        }
        .sheet(isPresented: $showLoginAlert) {
            LoginView()
        }
        .sheet(isPresented: $showImportSheet) {
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

// MARK: - Favorites View
struct FavoritesView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var playerService: AudioPlayerService
    @State private var favorites: [FavoriteMusic] = []
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if favorites.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "heart")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("还没有收藏的音乐")
                        .foregroundColor(.gray)
                }
            } else {
                List {
                    Button {
                        let musics = favorites.map { fav in
                            Music(id: fav.id, title: fav.title, artist: fav.artist, album: fav.album,
                                  duration: fav.duration, filePath: nil, coverFilePath: fav.cover,
                                  uploadUserId: nil, createdAt: nil, playCount: nil, lrc: nil)
                        }
                        playerService.setPlaylist(musics)
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("播放全部")
                        }
                        .foregroundColor(.pink)
                    }
                    
                    ForEach(favorites) { fav in
                        HStack(spacing: 12) {
                            RemoteImage(url: APIConfig.buildMusicCoverURL(musicId: fav.id, coverFilePath: fav.cover)) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.gray.opacity(0.2))
                                    .overlay(Image(systemName: "music.note").font(.caption).foregroundColor(.gray))
                            }
                            .frame(width: 48, height: 48)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(fav.title).font(.body).lineLimit(1)
                                Text(fav.artist).font(.caption).foregroundColor(.secondary).lineLimit(1)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            let music = Music(id: fav.id, title: fav.title, artist: fav.artist, album: fav.album,
                                              duration: fav.duration, filePath: nil, coverFilePath: fav.cover,
                                              uploadUserId: nil, createdAt: nil, playCount: nil, lrc: nil)
                            playerService.playMusic(music)
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("我的收藏")
        .task {
            await loadFavorites()
        }
    }
    
    private func loadFavorites() async {
        guard let token = authService.token else { return }
        
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

// MARK: - Playlists View
struct PlaylistsView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var playerService: AudioPlayerService
    @State private var playlists: [PlaylistInfo] = []
    @State private var isLoading = true
    @State private var showCreateSheet = false
    @State private var newPlaylistName = ""
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
            } else if playlists.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("还没有创建歌单")
                        .foregroundColor(.gray)
                    Button("创建歌单") {
                        showCreateSheet = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.pink)
                }
            } else {
                List {
                    ForEach(playlists) { playlist in
                        NavigationLink {
                            PlaylistDetailView(playlistId: playlist.id, playlistName: playlist.name)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "music.note.list")
                                    .foregroundColor(.purple)
                                    .frame(width: 40, height: 40)
                                    .background(Color.purple.opacity(0.1))
                                    .cornerRadius(6)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(playlist.name)
                                        .font(.body)
                                    Text("\(playlist.musicCount) 首")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("我的歌单")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .alert("创建歌单", isPresented: $showCreateSheet) {
            TextField("歌单名称", text: $newPlaylistName)
            Button("创建") {
                Task { await createPlaylist() }
            }
            Button("取消", role: .cancel) {
                newPlaylistName = ""
            }
        }
        .task {
            await loadPlaylists()
        }
    }
    
    private func loadPlaylists() async {
        guard let token = authService.token else { return }
        
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
