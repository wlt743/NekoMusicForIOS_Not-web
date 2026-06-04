import Foundation

class MusicService {
    static let shared = MusicService()
    
    private init() {}
    
    // MARK: - Search
    
    func searchMusic(query: String) async throws -> [Music] {
        let url = APIConfig.musicSearchURL()
        guard let requestURL = URL(string: url) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["query": query]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        return try parseMusicsFromResponse(data: data, errorHint: "搜索失败", dataKey: "results")
    }
    
    // MARK: - Ranking
    
    func getRanking(limit: Int = 8) async throws -> [Music] {
        let url = APIConfig.musicRankingURL(limit: limit)
        guard let requestURL = URL(string: url) else {
            throw NetworkError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: requestURL)
        return try parseMusicsFromResponse(data: data, errorHint: "获取排行榜失败", dataKey: "data")
    }
    
    // MARK: - Latest
    
    func getLatest(limit: Int = 300) async throws -> [Music] {
        let url = APIConfig.musicLatestURL(limit: limit)
        guard let requestURL = URL(string: url) else {
            throw NetworkError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: requestURL)
        return try parseMusicsFromResponse(data: data, errorHint: "获取最新音乐失败", dataKey: "data")
    }
    
    // MARK: - Parse Response
    
    private func parseMusicsFromResponse(data: Data, errorHint: String, dataKey: String) throws -> [Music] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Maybe it's a direct array
            if let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                return Music.fromJSONArray(array)
            }
            throw NetworkError.serverError(errorHint)
        }
        
        // Check success
        let isSuccess: Bool
        if let b = json["success"] as? Bool {
            isSuccess = b
        } else if let i = json["success"] as? Int {
            isSuccess = i != 0
        } else {
            isSuccess = true
        }
        
        if !isSuccess {
            let message = json["message"] as? String ?? errorHint
            throw NetworkError.serverError(message)
        }
        
        // Try the specified data key first, then alternative keys
        let musicArray: [[String: Any]]?
        if let arr = json[dataKey] as? [[String: Any]] {
            musicArray = arr
        } else if dataKey != "data", let arr = json["data"] as? [[String: Any]] {
            musicArray = arr
        } else if dataKey != "results", let arr = json["results"] as? [[String: Any]] {
            musicArray = arr
        } else {
            musicArray = nil
        }
        
        guard let array = musicArray else {
            return []
        }
        
        return Music.fromJSONArray(array)
    }
    
    // MARK: - Lyrics
    
    func getLyrics(musicId: Int) async throws -> String {
        let url = APIConfig.musicLyricsURL(id: musicId)
        guard let requestURL = URL(string: url) else {
            throw NetworkError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: requestURL)
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return ""
        }
        
        let success = json["success"] as? Bool ?? false
        if success, let lyricsData = json["data"] as? String {
            return lyricsData
        }
        return ""
    }
    
    // MARK: - Daily Recommendations
    
    func getDailyRecommendations(token: String) async throws -> [Music] {
        let url = APIConfig.dailyRecommendationsURL()
        guard let requestURL = URL(string: url) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: requestURL)
        request.setValue(token, forHTTPHeaderField: "Authorization")
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let success = json["success"] as? Bool, success,
              let dataArray = json["data"] as? [[String: Any]] else {
            return []
        }
        
        return dataArray.compactMap { item in
            guard let musicId = item["musicId"] as? Int else { return nil }
            return Music(
                id: musicId,
                title: item["title"] as? String ?? "未知歌曲",
                artist: item["artist"] as? String ?? "未知歌手",
                album: item["album"] as? String ?? "",
                duration: 0,
                filePath: nil,
                coverFilePath: nil,
                uploadUserId: nil,
                createdAt: nil,
                playCount: nil,
                lrc: nil
            )
        }
    }
    
    // MARK: - Music Info
    
    func getMusicInfo(id: Int) async throws -> Music {
        let url = APIConfig.musicInfoURL(id: id)
        guard let requestURL = URL(string: url) else {
            throw NetworkError.invalidURL
        }
        
        let (data, _) = try await URLSession.shared.data(from: requestURL)
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let success = json["success"] as? Bool, success,
              let musicData = json["data"] as? [String: Any],
              let music = Music.fromJSON(musicData) else {
            throw NetworkError.serverError("获取音乐信息失败")
        }
        
        return music
    }
    
    // MARK: - URLs
    
    func getMusicFileURL(musicId: Int) -> URL? {
        URL(string: APIConfig.musicFileURL(id: musicId))
    }
    
    func getMusicCoverURL(music: Music) -> URL? {
        let urlString = APIConfig.buildMusicCoverURL(musicId: music.id, coverFilePath: music.coverFilePath)
        return URL(string: urlString)
    }
}
