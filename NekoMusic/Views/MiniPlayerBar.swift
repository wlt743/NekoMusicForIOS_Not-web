import SwiftUI

struct MiniPlayerBar: View {
    @EnvironmentObject var playerService: AudioPlayerService
    @Binding var showNowPlaying: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Cover
            if let music = playerService.currentMusic {
                RemoteImage(url: APIConfig.buildMusicCoverURL(musicId: music.id, coverFilePath: music.coverFilePath)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.caption)
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            
            // Title & Artist
            VStack(alignment: .leading, spacing: 2) {
                Text(playerService.currentMusic?.title ?? "")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(playerService.currentMusic?.artist ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Play/Pause Button
            Button {
                playerService.togglePlayPause()
            } label: {
                Image(systemName: playerService.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            
            // Next Button
            Button {
                playerService.next()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.body)
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay(
            // Progress indicator
            GeometryReader { geo in
                let progress = playerService.duration > 0
                    ? playerService.currentPosition / playerService.duration
                    : 0
                
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.clear)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Color.pink)
                            .frame(width: geo.size.width * progress, height: 2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        )
        .padding(.horizontal, 8)
        .onTapGesture {
            showNowPlaying = true
        }
    }
}
