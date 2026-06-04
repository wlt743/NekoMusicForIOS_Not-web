import Foundation

// MARK: - Netease Models

struct NeteasePlaylistDetailResponse: Codable {
    let code: Int?
    let message: String?
    let msg: String?
    let playlist: NeteasePlaylistData?
}

struct NeteasePlaylistData: Codable {
    let id: Int?
    let name: String?
    let trackCount: Int?
    let tracks: [NeteaseTrack]?
}

struct NeteaseTrack: Codable {
    let name: String?
    let ar: [NeteaseArtist]?
}

struct NeteaseArtist: Codable {
    let name: String?
}

// MARK: - QQ Music Models

struct QqSongListDetailResponse: Codable {
    let response: QqSongListResponseBody?
}

struct QqSongListResponseBody: Codable {
    let code: Int?
    let cdnum: Int?
    let cdlist: [QqCd]?
}

struct QqCd: Codable {
    let disstid: String?
    let dissname: String?
    let songnum: Int?
    let songlist: [QqTrack]?
}

struct QqTrack: Codable {
    let name: String?
    let title: String?
    let singer: [QqSinger]?
}

struct QqSinger: Codable {
    let name: String?
}

// MARK: - Import Result

struct ImportResult {
    let playlistName: String
    let totalTracks: Int
    let matchedCount: Int
    let failedCount: Int
    let matchedMusicIds: [Int]
    let failedItems: [(title: String, artist: String)]
}

// MARK: - Playlist Import Service

class PlaylistImportService {
    static let shared = PlaylistImportService()
    private init() {}
    
    // MARK: - URL Parsing
    
    /// Parse Netease playlist ID from URL or raw ID
    func parseNeteasePlaylistId(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        
        // Pure numeric ID
        if trimmed.allSatisfy({ $0.isNumber }) { return trimmed }
        
        // playlist?id=123
        if let match = trimmed.range(of: #"playlist\?id=(\d+)"#, options: .regularExpression) {
            let sub = trimmed[match]
            if let idRange = sub.range(of: #"(\d+)$"#, options: .regularExpression) {
                return String(sub[idRange])
            }
        }
        
        // ?id=123 or &id=123
        if let match = trimmed.range(of: #"[?&]id=(\d+)"#, options: .regularExpression) {
            let sub = String(trimmed[match])
            let parts = sub.split(separator: "=")
            if parts.count == 2 { return String(parts[1]) }
        }
        
        // playlist/123
        if let match = trimmed.range(of: #"playlist/(\d+)"#, options: .regularExpression) {
            let sub = trimmed[match]
            if let idRange = sub.range(of: #"(\d+)"#, options: .regularExpression) {
                return String(sub[idRange])
            }
        }
        
        return nil
    }
    
    /// Parse QQ Music playlist ID from URL or raw ID
    func parseQQPlaylistId(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        
        // Pure numeric ID
        if trimmed.allSatisfy({ $0.isNumber }) { return trimmed }
        
        // ?id=123 or &id=123
        if let match = trimmed.range(of: #"[?&]id=(\d+)"#, options: .regularExpression) {
            let sub = String(trimmed[match])
            let parts = sub.split(separator: "=")
            if parts.count == 2 { return String(parts[1]) }
        }
        
        // disstid=123
        if let match = trimmed.range(of: #"disstid=(\d+)"#, options: .regularExpression) {
            let sub = String(trimmed[match])
            let parts = sub.split(separator: "=")
            if parts.count == 2 { return String(parts[1]) }
        }
        
        return nil
    }
    
    // MARK: - Fetch Netease Playlist
    
    func fetchNeteasePlaylist(playlistId: String) async throws -> (name: String, tracks: [(title: String, artist: String)]) {
        let url = "\(APIConfig.baseURL)/loser/playlist/detail?id=\(playlistId)"
        guard let requestURL = URL(string: url) else {
            throw NetworkError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: requestURL)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .useDefaultKeys
        let response = try decoder.decode(NeteasePlaylistDetailResponse.self, from: data)
        
        guard let playlist = response.playlist, let tracks = playlist.tracks, !tracks.isEmpty else {
            let errMsg = response.message ?? response.msg ?? "歌单不存在或为空"
            throw NetworkError.serverError(errMsg)
        }
        
        let name = playlist.name ?? "网易云歌单"
        let parsedTracks: [(String, String)] = tracks.compactMap { track in
            guard let title = track.name, !title.trimmingCharacters(in: .whitespaces).isEmpty else {
                return nil
            }
            let artist = track.ar?.compactMap { $0.name?.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: " / ") ?? ""
            return (title.trimmingCharacters(in: .whitespaces), artist)
        }
        
        return (name, parsedTracks)
    }
    
    // MARK: - Fetch QQ Music Playlist
    
    func fetchQQPlaylist(disstid: String) async throws -> (name: String, tracks: [(title: String, artist: String)]) {
        let url = "\(APIConfig.baseURL)/loser1/getSongListDetail?disstid=\(disstid)"
        guard let requestURL = URL(string: url) else {
            throw NetworkError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: requestURL)
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(QqSongListDetailResponse.self, from: data)
        
        guard let body = response.response, let cdlist = body.cdlist, !cdlist.isEmpty else {
            throw NetworkError.serverError("QQ音乐歌单不存在或为空")
        }
        
        let allTracks = cdlist.flatMap { $0.songlist ?? [] }
        guard !allTracks.isEmpty else {
            throw NetworkError.serverError("歌单无曲目")
        }
        
        let name = cdlist.first?.dissname ?? "QQ音乐歌单"
        let parsedTracks: [(String, String)] = allTracks.compactMap { track in
            let title = (track.name ?? track.title ?? "").trimmingCharacters(in: .whitespaces)
            guard !title.isEmpty else { return nil }
            let artist = track.singer?.compactMap { $0.name?.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: " / ") ?? ""
            return (title, artist)
        }
        
        return (name, parsedTracks)
    }
    
    // MARK: - Batch Search & Match
    
    private let chunkSize = 20
    
    /// Uses Neko's batch search API to find matching songs, 20 items per chunk
    func matchTracksInLibrary(tracks: [(title: String, artist: String)]) async throws -> (matched: [Music], failed: [(title: String, artist: String)]) {
        guard !tracks.isEmpty else {
            return ([], [])
        }
        
        var allMatched: [Music] = []
        var allFailed: [(String, String)] = []
        
        // Split into chunks of 20
        let chunks = stride(from: 0, to: tracks.count, by: chunkSize).map {
            Array(tracks[$0..<min($0 + chunkSize, tracks.count)])
        }
        
        for chunk in chunks {
            let (matched, failed) = try await searchChunk(chunk)
            allMatched.append(contentsOf: matched)
            allFailed.append(contentsOf: failed)
        }
        
        return (allMatched, allFailed)
    }
    
    /// Search a single chunk (up to 20 items)
    private func searchChunk(_ tracks: [(title: String, artist: String)]) async throws -> (matched: [Music], failed: [(title: String, artist: String)]) {
        let items = tracks.map { SearchItem(title: $0.0, artist: $0.1) }
        let body = BatchSearchRequest(items: items)
        
        let url = APIConfig.musicSearchURL()
        guard let requestURL = URL(string: url) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)
        
        let data: Data
        do {
            let (responseData, _) = try await URLSession.shared.data(for: request)
            data = responseData
        } catch {
            let nsError = error as NSError
            if nsError.code == NSURLErrorTimedOut || nsError.code == NSURLErrorNetworkConnectionLost {
                throw NetworkError.serverBusy
            }
            throw NetworkError.serverBusy
        }
        
        // Parse response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let success = json?["success"] as? Bool ?? false
        
        guard success else {
            let message = json?["message"] as? String ?? "服务器繁忙，请稍后再试"
            throw NetworkError.serverError(message)
        }
        
        var matched: [Music] = []
        var failed: [(String, String)] = []
        
        if let resultsArray = json?["results"] as? [Any] {
            for (index, result) in resultsArray.enumerated() {
                if index >= tracks.count { break }
                
                if result is NSNull {
                    failed.append(tracks[index])
                } else if let musicDict = result as? [String: Any],
                          let music = Music.fromJSON(musicDict) {
                    matched.append(music)
                } else {
                    failed.append(tracks[index])
                }
            }
        }
        
        return (matched, failed)
    }
    
    // MARK: - Full Import Flow
    
    func importNeteasePlaylist(playlistId: String, token: String?) async throws -> ImportResult {
        // 1. Fetch playlist
        let (name, tracks) = try await fetchNeteasePlaylist(playlistId: playlistId)
        
        // 2. Match tracks
        let (matched, failed) = try await matchTracksInLibrary(tracks: tracks)
        
        // 3. Create a new playlist and add matched songs
        if let token = token, !matched.isEmpty {
            let musicIds = matched.map { $0.id }
            _ = try? await createPlaylistAndAddMusic(token: token, name: name, musicIds: musicIds)
        }
        
        return ImportResult(
            playlistName: name,
            totalTracks: tracks.count,
            matchedCount: matched.count,
            failedCount: failed.count,
            matchedMusicIds: matched.map { $0.id },
            failedItems: failed
        )
    }
    
    func importQQPlaylist(disstid: String, token: String?) async throws -> ImportResult {
        // 1. Fetch playlist
        let (name, tracks) = try await fetchQQPlaylist(disstid: disstid)
        
        // 2. Match tracks
        let (matched, failed) = try await matchTracksInLibrary(tracks: tracks)
        
        // 3. Create a new playlist and add matched songs
        if let token = token, !matched.isEmpty {
            let musicIds = matched.map { $0.id }
            _ = try? await createPlaylistAndAddMusic(token: token, name: name, musicIds: musicIds)
        }
        
        return ImportResult(
            playlistName: name,
            totalTracks: tracks.count,
            matchedCount: matched.count,
            failedCount: failed.count,
            matchedMusicIds: matched.map { $0.id },
            failedItems: failed
        )
    }
    
    // MARK: - Create Playlist & Add Music
    
    /// Create a new playlist with the given name and add all matched music IDs to it
    private func createPlaylistAndAddMusic(token: String, name: String, musicIds: [Int]) async throws {
        // Step 1: Create the playlist
        struct CreatePlaylistRequest: Codable {
            let name: String
        }
        
        struct CreatePlaylistResponse: Codable {
            let success: Bool
            let message: String?
            let playlist: CreatedPlaylist?
        }
        
        struct CreatedPlaylist: Codable {
            let id: Int
            let name: String?
        }
        
        let createBody = CreatePlaylistRequest(name: name)
        let createResponse: CreatePlaylistResponse = try await NetworkService.shared.post(
            url: APIConfig.playlistCreateURL(),
            body: createBody,
            token: token
        )
        
        guard createResponse.success, let newPlaylist = createResponse.playlist else {
            print("创建歌单失败: \(createResponse.message ?? "")")
            return
        }
        
        // Step 2: Add music to the new playlist
        struct AddMusicsRequest: Codable {
            let playlistId: Int
            let musicIds: [Int]
        }
        
        struct AddMusicsResponse: Codable {
            let success: Bool
            let message: String?
        }
        
        let addBody = AddMusicsRequest(playlistId: newPlaylist.id, musicIds: musicIds)
        let _: AddMusicsResponse = try await NetworkService.shared.post(
            url: APIConfig.playlistAddMusicURL(),
            body: addBody,
            token: token
        )
    }
}
