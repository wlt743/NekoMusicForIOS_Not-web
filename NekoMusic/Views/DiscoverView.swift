import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject var playerService: AudioPlayerService
    @State private var searchText = ""
    @State private var searchResults: [Music] = []
    @State private var isSearching = false
    @State private var hasSearched = false
    @State private var playlists: [PlaylistInfo] = []
    @State private var isLoadingPlaylists = true
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("搜索音乐、歌手", text: $searchText)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            Task { await performSearch() }
                        }
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            searchResults = []
                            hasSearched = false
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 8)
                
                if isSearching {
                    Spacer()
                    ProgressView("搜索中...")
                    Spacer()
                } else if hasSearched {
                    // Search Results
                    if searchResults.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 48))
                                .foregroundColor(.gray)
                            Text("未找到相关音乐")
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    } else {
                        List {
                            ForEach(searchResults) { music in
                                MusicRowView(music: music)
                                    .listRowInsets(EdgeInsets())
                                    .onTapGesture {
                                        playerService.setPlaylist(searchResults, startAt: searchResults.firstIndex(of: music) ?? 0)
                                    }
                            }
                        }
                        .listStyle(.plain)
                    }
                } else {
                    // Recommended Playlists
                    if isLoadingPlaylists {
                        Spacer()
                        ProgressView()
                        Spacer()
                    } else if !playlists.isEmpty {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("推荐歌单")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal)
                                    .padding(.top, 16)
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 16) {
                                    ForEach(playlists) { playlist in
                                        NavigationLink {
                                            PlaylistDetailView(playlistId: playlist.id, playlistName: playlist.name)
                                        } label: {
                                            PlaylistCardView(playlist: playlist)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal)
                                
                                Color.clear.frame(height: 80)
                            }
                        }
                    } else {
                        Spacer()
                        Text("输入关键词搜索音乐")
                            .foregroundColor(.gray)
                        Spacer()
                    }
                }
            }
            .navigationTitle("发现")
        }
        .task {
            await loadPlaylists()
        }
    }
    
    private func performSearch() async {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        isSearching = true
        hasSearched = true
        
        do {
            let results = try await MusicService.shared.searchMusic(query: searchText)
            await MainActor.run {
                self.searchResults = results
                self.isSearching = false
            }
        } catch {
            await MainActor.run {
                self.searchResults = []
                self.isSearching = false
            }
        }
    }
    
    private func loadPlaylists() async {
        do {
            struct SearchBody: Codable {
                let query: String
            }
            let response: PlaylistListResponse = try await NetworkService.shared.post(
                url: APIConfig.playlistSearchURL(),
                body: SearchBody(query: "")
            )
            await MainActor.run {
                self.playlists = response.playlists ?? response.results ?? []
                self.isLoadingPlaylists = false
            }
        } catch {
            await MainActor.run {
                self.isLoadingPlaylists = false
            }
        }
    }
}

// MARK: - Playlist Card View
struct PlaylistCardView: View {
    let playlist: PlaylistInfo
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Cover
            let coverURL = playlist.coverPath ?? playlist.firstMusicCover
            AsyncImage(url: URL(string: APIConfig.buildFullURL(path: coverURL ?? ""))) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [.pink.opacity(0.3), .purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Image(systemName: "music.note.list")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.8))
                    )
            }
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Text(playlist.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
            
            Text("\(playlist.musicCount) 首")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
