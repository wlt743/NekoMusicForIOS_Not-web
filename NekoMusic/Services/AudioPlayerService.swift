import Foundation
import UIKit
import AVFoundation
import MediaPlayer
import Combine

enum PlayMode: String, CaseIterable {
    case listLoop = "LIST_LOOP"
    case singleLoop = "SINGLE_LOOP"
    case shuffle = "SHUFFLE"
    
    var icon: String {
        switch self {
        case .listLoop: return "repeat"
        case .singleLoop: return "repeat.1"
        case .shuffle: return "shuffle"
        }
    }
    
    var displayName: String {
        switch self {
        case .listLoop: return "列表循环"
        case .singleLoop: return "单曲循环"
        case .shuffle: return "随机播放"
        }
    }
}

class AudioPlayerService: ObservableObject {
    static let shared = AudioPlayerService()
    
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    
    @Published var isPlaying: Bool = false
    @Published var currentPosition: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var currentMusic: Music?
    @Published var playMode: PlayMode = .listLoop
    @Published var isFavorite: Bool = false
    @Published var playlist: [Music] = []
    @Published var currentLyrics: String = ""
    
    private var playHistory: [Int] = []
    private var cancellables = Set<AnyCancellable>()
    private var artworkCache: [Int: MPMediaItemArtwork] = [:]
    private var lastInfoSync: Date = .distantPast
    
    private init() {
        setupAudioSession()
        setupRemoteTransportControls()
        setupNotifications()
        loadPlayMode()
    }
    
    // MARK: - Audio Session
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: []
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("AudioSession setup error: \(error)")
        }
    }
    
    // MARK: - Remote Controls (Lock Screen / Control Center)
    
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            self?.next()
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            self?.previous()
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self?.seekTo(position: event.positionTime)
            return .success
        }
    }
    
    private func updateNowPlayingInfo() {
        guard let music = currentMusic else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: music.title,
            MPMediaItemPropertyArtist: music.artist,
            MPMediaItemPropertyAlbumTitle: music.album,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentPosition,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyIsLiveStream: false,
            MPNowPlayingInfoPropertyExternalContentIdentifier: "nekomusic:\(music.id)",
            MPNowPlayingInfoPropertyPlaybackQueueCount: playlist.count,
            MPNowPlayingInfoPropertyPlaybackQueueIndex: playlist.firstIndex(where: { $0.id == music.id }) ?? 0,
        ]

        if let artwork = artworkCache[music.id] {
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
        lastInfoSync = Date()

        loadArtworkIfNeeded(for: music)
    }

    /// 封面按歌曲缓存，避免每次刷新 Now Playing 都重新下载
    private func loadArtworkIfNeeded(for music: Music) {
        guard artworkCache[music.id] == nil else { return }

        let coverPath = APIConfig.buildMusicCoverURL(musicId: music.id, coverFilePath: music.coverFilePath)
        guard URL(string: coverPath) != nil else { return }

        Task { [weak self] in
            guard let self = self else { return }
            do {
                let data = try await NetworkService.shared.fetchData(url: coverPath)
                guard let image = UIImage(data: data) else { return }
                let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }

                await MainActor.run {
                    self.artworkCache[music.id] = artwork
                    guard self.currentMusic?.id == music.id else { return }

                    var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                    info[MPMediaItemPropertyArtwork] = artwork
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                }
            } catch {
                print("Load now playing artwork failed: \(error)")
            }
        }
    }

    /// 播放中节流更新进度，保证控制中心/锁屏进度条平滑
    private func syncElapsedTime() {
        guard let music = currentMusic else { return }

        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPMediaItemPropertyTitle] = music.title
        info[MPMediaItemPropertyArtist] = music.artist
        info[MPMediaItemPropertyAlbumTitle] = music.album
        info[MPMediaItemPropertyPlaybackDuration] = duration
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentPosition
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        MPNowPlayingInfoCenter.default().playbackState = isPlaying ? .playing : .paused
        lastInfoSync = Date()
    }

    // MARK: - 音频中断 / 线路变化

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: raw) else { return }

            switch type {
            case .began:
                self.pause()
            case .ended:
                let options = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                if AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume) {
                    self.play()
                }
            @unknown default:
                break
            }
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let raw = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: raw) else { return }

            if reason == .oldDeviceUnavailable {
                self.pause()
            }
        }
    }

    // MARK: - Playback Controls
    
    func playMusic(_ music: Music) {
        // 记录历史
        if currentMusic?.id != music.id {
            if let currentId = currentMusic?.id {
                playHistory.append(currentId)
            }
        }

        currentMusic = music
        duration = 0
        currentPosition = 0
        currentLyrics = ""

        // 加入当前播放列表
        if !playlist.contains(where: { $0.id == music.id }) {
            playlist.append(music)
        }

        // 后端新接口需要先换取真正的音频地址（带 nonce），拿到后再播放
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let url = try await MusicService.shared.resolveAudioURL(musicId: music.id)
                await MainActor.run {
                    guard self.currentMusic?.id == music.id else { return }
                    self.startPlayback(url: url)
                }
            } catch {
                print("Resolve audio url error: \(error)")
                await MainActor.run {
                    guard self.currentMusic?.id == music.id else { return }
                    self.isPlaying = false
                }
            }
        }

        updateNowPlayingInfo()
        checkFavoriteStatus()
        loadLyrics()
    }

    private func startPlayback(url: URL) {
        // 换歌时清掉上一首的订阅，避免累积
        cancellables.removeAll()

        playerItem = AVPlayerItem(url: url)

        if player == nil {
            player = AVPlayer(playerItem: playerItem)
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }

        // 观察时长
        playerItem?.publisher(for: \.duration)
            .compactMap { $0.isNumeric ? CMTimeGetSeconds($0) : nil }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] dur in
                self?.duration = dur
                self?.syncElapsedTime()
            }
            .store(in: &cancellables)

        // 观察播放结束
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handlePlaybackEnd()
            }
            .store(in: &cancellables)

        // 开始进度跟踪
        startPositionTracking()

        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
    }
    
    func play() {
        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func seekTo(position: TimeInterval) {
        let time = CMTime(seconds: position, preferredTimescale: 600)
        player?.seek(to: time)
        currentPosition = position
        updateNowPlayingInfo()
    }
    
    func next() {
        guard let music = currentMusic else { return }
        
        switch playMode {
        case .listLoop:
            if let index = playlist.firstIndex(where: { $0.id == music.id }) {
                let nextIndex = (index + 1) % playlist.count
                playMusic(playlist[nextIndex])
            }
        case .singleLoop:
            // When user manually presses next, go to next song
            if let index = playlist.firstIndex(where: { $0.id == music.id }) {
                let nextIndex = (index + 1) % playlist.count
                playMusic(playlist[nextIndex])
            }
        case .shuffle:
            let availableMusic = playlist.filter { $0.id != music.id }
            if let randomMusic = availableMusic.randomElement() {
                playMusic(randomMusic)
            }
        }
    }
    
    func previous() {
        guard let music = currentMusic else { return }
        
        // Try to go back in history first
        if let lastId = playHistory.popLast(),
           let previousMusic = playlist.first(where: { $0.id == lastId }) {
            playMusic(previousMusic)
            return
        }
        
        // Otherwise go to previous in list
        if let index = playlist.firstIndex(where: { $0.id == music.id }) {
            let prevIndex = (index - 1 + playlist.count) % playlist.count
            playMusic(playlist[prevIndex])
        }
    }
    
    func togglePlayMode() {
        switch playMode {
        case .listLoop: playMode = .singleLoop
        case .singleLoop: playMode = .shuffle
        case .shuffle: playMode = .listLoop
        }
        savePlayMode()
    }
    
    // MARK: - Playlist Management
    
    func setPlaylist(_ musics: [Music], startAt index: Int = 0) {
        playlist = musics
        if index < musics.count {
            playMusic(musics[index])
        }
    }
    
    // MARK: - Private Methods
    
    private func startPositionTracking() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
        }
        
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentPosition = CMTimeGetSeconds(time)

            if Date().timeIntervalSince(self.lastInfoSync) >= 1.0 {
                self.syncElapsedTime()
            }
        }
    }
    
    private func handlePlaybackEnd() {
        switch playMode {
        case .singleLoop:
            seekTo(position: 0)
            play()
        case .listLoop, .shuffle:
            next()
        }
    }
    
    private func checkFavoriteStatus() {
        guard let music = currentMusic,
              let token = AuthService.shared.token else {
            isFavorite = false
            return
        }
        
        Task {
            let result = await FavoriteService.shared.isFavorited(token: token, musicId: music.id)
            await MainActor.run {
                self.isFavorite = result
            }
        }
    }
    
    func toggleFavorite() {
        guard let music = currentMusic,
              let token = AuthService.shared.token else { return }
        
        Task {
            do {
                if isFavorite {
                    _ = try await FavoriteService.shared.removeFavorite(token: token, musicId: music.id)
                } else {
                    _ = try await FavoriteService.shared.addFavorite(token: token, musicId: music.id)
                }
                await MainActor.run {
                    self.isFavorite.toggle()
                }
            } catch {
                print("Toggle favorite error: \(error)")
            }
        }
    }
    
    private func loadLyrics() {
        guard let music = currentMusic else {
            currentLyrics = ""
            return
        }
        
        Task {
            do {
                let lyrics = try await MusicService.shared.getLyrics(musicId: music.id)
                await MainActor.run {
                    self.currentLyrics = lyrics
                }
            } catch {
                await MainActor.run {
                    self.currentLyrics = ""
                }
            }
        }
    }
    
    // MARK: - Persistence
    
    private func loadPlayMode() {
        if let savedMode = UserDefaults.standard.string(forKey: "play_mode"),
           let mode = PlayMode(rawValue: savedMode) {
            playMode = mode
        }
    }
    
    private func savePlayMode() {
        UserDefaults.standard.set(playMode.rawValue, forKey: "play_mode")
    }
}
