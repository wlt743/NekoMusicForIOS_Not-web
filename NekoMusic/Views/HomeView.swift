import SwiftUI

struct HomeView: View {
    @EnvironmentObject var playerService: AudioPlayerService

    @State private var rankingMusic: [Music] = []
    @State private var latestMusic: [Music] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("加载中…")
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    EmptyStateView(
                        title: "加载失败",
                        systemImage: "wifi.exclamationmark",
                        description: error,
                        actionTitle: "重试"
                    ) {
                        Task { await loadData() }
                    }
                } else {
                    content
                }
            }
            .navigationTitle("NekoMusic")
            .refreshable { await loadData() }
            .task {
                if rankingMusic.isEmpty && latestMusic.isEmpty {
                    await loadData()
                }
            }
        }
    }

    private var content: some View {
        List {
            if !rankingMusic.isEmpty {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            ForEach(rankingMusic.prefix(8)) { music in
                                Button {
                                    play(rankingMusic, music)
                                } label: {
                                    MusicCard(music: music)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 0, leading: Layout.horizontalPadding, bottom: 0, trailing: Layout.horizontalPadding))
                    .listRowBackground(Color.clear)
                } header: {
                    sectionHeader(
                        "热门排行",
                        systemImage: "flame",
                        destination: MusicListView(title: "热门排行", musics: rankingMusic)
                    )
                }
            }

            if !latestMusic.isEmpty {
                Section {
                    ForEach(latestMusic.prefix(10)) { music in
                        Button {
                            play(latestMusic, music)
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
                    sectionHeader(
                        "最新上架",
                        systemImage: "music.note",
                        destination: MusicListView(title: "最新上架", musics: latestMusic)
                    )
                }
            }
        }
        .listStyle(.plain)
    }

    private func sectionHeader(_ title: String, systemImage: String, destination: some View) -> some View {
        HStack(alignment: .firstTextBaseline) {
            SectionHeader(title: title, systemImage: systemImage)
            Spacer()
            NavigationLink("更多", destination: destination)
                .font(.subheadline)
        }
    }

    private func play(_ list: [Music], _ music: Music) {
        let index = list.firstIndex(of: music) ?? 0
        playerService.setPlaylist(list, startAt: index)
    }

    private func loadData() async {
        if rankingMusic.isEmpty && latestMusic.isEmpty {
            isLoading = true
        }
        errorMessage = nil

        do {
            async let ranking = MusicService.shared.getRanking()
            async let latest = MusicService.shared.getLatest()

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

// MARK: - 横向卡片

struct MusicCard: View {
    let music: Music

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CoverImage(
                url: APIConfig.buildMusicCoverURL(musicId: music.id, coverFilePath: music.coverFilePath),
                size: 140,
                cornerRadius: Layout.cardRadius
            )

            Text(music.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)

            Text(music.artist)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 140, alignment: .leading)
    }
}
