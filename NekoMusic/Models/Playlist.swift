import Foundation

struct Playlist: Codable, Identifiable {
    let id: Int
    let name: String
    let musicCount: Int
    let userId: Int?
    let createdAt: String
    let coverPath: String?
    let description: String?
    let username: String?
    let creatorAvatar: String?
}

struct PlaylistInfo: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let coverPath: String?
    let musicCount: Int
    let createdAt: String
    let updatedAt: String
    let userId: Int?
    let username: String?
    let creatorAvatar: String?
    let firstMusicCover: String?
}

struct PlaylistMusic: Codable, Identifiable {
    let id: Int
    let title: String
    let artist: String
    let album: String
    let duration: Int
    let coverPath: String?
    let filePath: String
    let fileFormat: String
    let language: String
    let position: Int
    let addedAt: String
}

struct PlaylistListResponse: Codable {
    let success: Bool
    let message: String?
    let playlists: [PlaylistInfo]?
    let results: [PlaylistInfo]?
    let isVip: Bool?
    let vipExpiresAt: String?
}

struct PlaylistResponse: Codable {
    let success: Bool
    let message: String?
    let playlist: PlaylistInfo?
}

struct PlaylistMusicListResponse: Codable {
    let success: Bool
    let message: String
    let playlistId: Int
    let total: Int
    let musicList: [PlaylistMusic]?
}

struct FavoriteMusic: Codable, Identifiable {
    let id: Int
    let title: String
    let artist: String
    let album: String
    let duration: Int
    let filename: String
    let cover: String?
}

struct FavoriteListResponse: Codable {
    let success: Bool
    let favorites: [FavoriteMusic]
}

struct FavoriteResponse: Codable {
    let success: Bool
    let message: String
}

struct FavoritePlaylistInfo: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let musicCount: Int
    let createdAt: Int?
    let updatedAt: Int?
    let favoriteTime: Int?
}

struct FavoritePlaylistListResponse: Codable {
    let success: Bool
    let playlists: [FavoritePlaylistInfo]
}
