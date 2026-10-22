import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var playerService: AudioPlayerService
    @State private var selectedTab = 0
    @State private var showNowPlaying = false

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem { Label("首页", systemImage: "house") }
                .tag(0)

            DiscoverView()
                .tabItem { Label("发现", systemImage: "magnifyingglass") }
                .tag(1)

            LibraryView()
                .tabItem { Label("音乐库", systemImage: "music.note.list") }
                .tag(2)

            ProfileView()
                .tabItem { Label("我的", systemImage: "person") }
                .tag(3)
        }
        .tint(.accentColor)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if playerService.currentMusic != nil {
                MiniPlayerBar(showNowPlaying: $showNowPlaying)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
            }
        }
        .fullScreenCover(isPresented: $showNowPlaying) {
            NowPlayingView()
                .environmentObject(playerService)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService.shared)
        .environmentObject(AudioPlayerService.shared)
}
