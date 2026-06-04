import Foundation

enum APIConfig {
    static let baseURL = "https://music.cnmsb.xin"
    
    // MARK: - Music APIs
    static func musicSearchURL() -> String { "\(baseURL)/api/music/search" }
    static func musicRankingURL(limit: Int = 8) -> String { "\(baseURL)/api/music/ranking?limit=\(limit)" }
    static func musicLatestURL(limit: Int = 300) -> String { "\(baseURL)/api/music/latest?limit=\(limit)" }
    static func musicFileURL(id: Int) -> String { "\(baseURL)/api/music/file/\(id)" }
    static func musicCoverURL(id: Int) -> String { "\(baseURL)/api/music/cover/\(id)" }
    static func musicLyricsURL(id: Int) -> String { "\(baseURL)/api/music/lyrics/\(id)" }
    static func musicInfoURL(id: Int) -> String { "\(baseURL)/api/music/info/\(id)" }
    
    // MARK: - User APIs
    static func loginURL() -> String { "\(baseURL)/api/user/login" }
    static func registerURL() -> String { "\(baseURL)/api/user/register" }
    static func sendVerificationURL() -> String { "\(baseURL)/api/user/send-verification" }
    static func sendResetCodeURL() -> String { "\(baseURL)/api/user/send-reset-code" }
    static func resetPasswordURL() -> String { "\(baseURL)/api/user/reset-password" }
    static func changePasswordURL() -> String { "\(baseURL)/api/user/password/change" }
    static func userAvatarURL(id: Int) -> String { "\(baseURL)/api/user/avatar/\(id)" }
    static func dailyRecommendationsURL() -> String { "\(baseURL)/api/user/recommendations/daily" }
    
    // MARK: - Favorite APIs
    static func favoritesURL() -> String { "\(baseURL)/api/user/favorites" }
    static func removeFavoriteURL(musicId: Int) -> String { "\(baseURL)/api/user/favorites/\(musicId)" }
    
    // MARK: - Playlist APIs
    static func playlistSearchURL() -> String { "\(baseURL)/api/playlists/search" }
    static func myPlaylistsURL() -> String { "\(baseURL)/api/user/playlists" }
    static func playlistCreateURL() -> String { "\(baseURL)/api/user/playlist/create" }
    static func playlistDeleteURL() -> String { "\(baseURL)/api/user/playlist/delete" }
    static func playlistMusicURL(id: Int) -> String { "\(baseURL)/api/user/playlist/music/\(id)" }
    static func playlistDetailURL(id: Int) -> String { "\(baseURL)/api/playlist/\(id)" }
    static func playlistAddMusicURL() -> String { "\(baseURL)/api/user/playlist/music/add" }
    static func playlistRemoveMusicURL() -> String { "\(baseURL)/api/user/playlist/music/remove" }
    
    // MARK: - Helpers
    static func buildFullURL(path: String) -> String {
        if path.hasPrefix("http") {
            return path
        }
        if path.hasPrefix("/") {
            return "\(baseURL)\(path)"
        }
        return path
    }
    
    static func buildMusicCoverURL(musicId: Int, coverFilePath: String?) -> String {
        if let coverPath = coverFilePath, !coverPath.isEmpty {
            if coverPath.hasPrefix("http") {
                return coverPath
            }
            if coverPath.hasPrefix("/") {
                return "\(baseURL)\(coverPath)"
            }
        }
        return musicCoverURL(id: musicId)
    }
}
