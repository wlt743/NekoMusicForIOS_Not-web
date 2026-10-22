import SwiftUI

struct MusicListView: View {
    @EnvironmentObject var playerService: AudioPlayerService
    let title: String
    let musics: [Music]
    
    var body: some View {
        List {
            // Play All Button
            Button {
                playerService.setPlaylist(musics)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                        .foregroundColor(.white)
                    Text("播放全部 (\(musics.count))")
                        .foregroundColor(.white)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [.pink, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(10)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            
            // Music List
            ForEach(Array(musics.enumerated()), id: \.element.id) { index, music in
                HStack(spacing: 12) {
                    Text("\(index + 1)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 24)
                    
                    RemoteImage(url: APIConfig.buildMusicCoverURL(musicId: music.id, coverFilePath: music.coverFilePath)) { image in
                        image.resizable().aspectRatio(contentMode: .fill)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.gray.opacity(0.2))
                            .overlay(Image(systemName: "music.note").font(.caption).foregroundColor(.gray))
                    }
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(music.title)
                            .font(.body)
                            .lineLimit(1)
                            .foregroundColor(playerService.currentMusic?.id == music.id ? .pink : .primary)
                        Text(music.artist)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    if playerService.currentMusic?.id == music.id {
                        Image(systemName: playerService.isPlaying ? "speaker.wave.2.fill" : "speaker.fill")
                            .foregroundColor(.pink)
                            .font(.caption)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    playerService.setPlaylist(musics, startAt: index)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(title)
    }
}
