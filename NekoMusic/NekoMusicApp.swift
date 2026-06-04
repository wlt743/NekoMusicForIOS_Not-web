import SwiftUI

@main
struct NekoMusicApp: App {
    @StateObject private var authService = AuthService.shared
    @StateObject private var playerService = AudioPlayerService.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(playerService)
        }
    }
}
