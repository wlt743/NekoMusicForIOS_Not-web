import SwiftUI

struct HomeView: View {
    @EnvironmentObject var playerService: AudioPlayerService
    @State private var rankingMusic: [Music] = []
    @State private var latestMusic: [Music] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Ranking Section
                    if !rankingMusic.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("🔥 热门排行")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Spacer()
                                NavigationLink("更多") {
                                    MusicListView(title: "热门排行", musics: rankingMusic)
                                }
                                .foregroundColor(.pink)
                            }
                            .padding(.horizontal)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 12) {
                                    ForEach(rankingMusic.prefix(8)) { music in
                                        MusicCardView(music: music)
                                            .onTapGesture {
                                                playerService.setPlaylist(rankingMusic, startAt: rankingMusic.firstIndex(of: music) ?? 0)
                                            }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // Latest Music Section
                    if !latestMusic.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("🎵 最新上架")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Spacer()
                                NavigationLink("更多") {
                                    MusicListView(title: "最新上架", musics: latestMusic)
                                }
                                .foregroundColor(.pink)
                            }
                            .padding(.horizontal)
                            
                            LazyVStack(spacing: 0) {
                                ForEach(latestMusic.prefix(10)) { music in
                                    MusicRowView(music: music)
                                        .onTapGesture {
                                            playerService.setPlaylist(latestMusic, startAt: latestMusic.firstIndex(of: music) ?? 0)
                                        }
                                }
                            }
                        }
                    }
                    
                    // Bottom padding for mini player
                    Color.clear.frame(height: 80)
                }
                .padding(.top)
            }
            .navigationTitle("NekoMusic")
            .refreshable {
                await loadData()
            }
            .overlay {
                if isLoading {
                    ProgressView("加载中...")
                }
                if let error = errorMessage {
                    VStack {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text(error)
                            .foregroundColor(.gray)
                        Button("重试") {
                            Task { await loadData() }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .task {
            await loadData()
        }
    }
    
    private func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            async let ranking = MusicService.shared.getRanking(limit: 8)
            async let latest = MusicService.shared.getLatest(limit: 50)
            
            let (rankingResult, latestResult) = try await (ranking, latest)
            
            await MainActor.run {
                self.rankingMusic = rankingResult
                self.latestMusic = latestResult
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

// MARK: - Music Card View (Horizontal scroll)
struct MusicCardView: View {
    let music: Music
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RemoteImage(url: APIConfig.buildMusicCoverURL(musicId: music.id, coverFilePath: music.coverFilePath)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 140, height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            Text(music.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
            
            Text(music.artist)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(width: 140)
    }
}

// MARK: - Music Row View (Vertical list)
struct MusicRowView: View {
    let music: Music
    
    var body: some View {
        HStack(spacing: 12) {
            RemoteImage(url: APIConfig.buildMusicCoverURL(musicId: music.id, coverFilePath: music.coverFilePath)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.2))
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.caption)
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(music.title)
                    .font(.body)
                    .lineLimit(1)
                
                Text(music.artist)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            if music.duration > 0 {
                Text(formatDuration(music.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let min = seconds / 60
        let sec = seconds % 60
        return String(format: "%d:%02d", min, sec)
    }
}
