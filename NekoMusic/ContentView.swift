import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var playerService: AudioPlayerService
    @State private var selectedTab = 0
    @State private var showNowPlaying = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Image(systemName: "house.fill")
                        Text("首页")
                    }
                    .tag(0)
                
                DiscoverView()
                    .tabItem {
                        Image(systemName: "magnifyingglass")
                        Text("发现")
                    }
                    .tag(1)
                
                LibraryView()
                    .tabItem {
                        Image(systemName: "music.note.list")
                        Text("音乐库")
                    }
                    .tag(2)
                
                ProfileView()
                    .tabItem {
                        Image(systemName: "person.fill")
                        Text("我的")
                    }
                    .tag(3)
            }
            .accentColor(.pink)
            
            // Mini Player Bar
            if playerService.currentMusic != nil {
                VStack(spacing: 0) {
                    Spacer()
                    MiniPlayerBar(showNowPlaying: $showNowPlaying)
                        .padding(.bottom, 49) // Tab bar height
                }
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
