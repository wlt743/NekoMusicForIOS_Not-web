import SwiftUI

@main
struct NekoMusicApp: App {
    @StateObject private var authService = AuthService.shared
    @StateObject private var playerService = AudioPlayerService.shared
    @StateObject private var appearance = AppearanceSettings.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(playerService)
                .environmentObject(appearance)
                .tint(appearance.tintColor)
        }
    }
}
