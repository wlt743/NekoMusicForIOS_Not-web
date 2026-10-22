import SwiftUI

/// 统一的设计约定。
/// 原则：优先使用系统组件与语义颜色（自动适配深色模式、动态字体与新版系统外观），
/// 仅在没有对应系统组件时才做少量自绘。
enum Layout {
    static let cardRadius: CGFloat = 12
    static let coverRadius: CGFloat = 8
    static let horizontalPadding: CGFloat = 16
    static let coverSize: CGFloat = 52
    static let miniCoverSize: CGFloat = 44
}

extension View {
    /// 系统液态玻璃（iOS 26+），旧系统回退到材质。
    @ViewBuilder
    func glassSurface<S: Shape>(_ shape: S) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
        }
    }
}

/// 列表分区标题，使用系统字体层级。
struct SectionHeader: View {
    let title: String
    var systemImage: String?

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage = systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(.tint)
            }
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textCase(nil)
    }
}

/// 空状态 / 错误状态，优先使用系统 ContentUnavailableView。
struct EmptyStateView: View {
    let title: String
    let systemImage: String
    var description: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        if #available(iOS 17.0, *) {
            ContentUnavailableView {
                Label(title, systemImage: systemImage)
            } description: {
                if let description = description {
                    Text(description)
                }
            } actions: {
                if let actionTitle = actionTitle, let action = action {
                    Button(actionTitle, action: action)
                        .buttonStyle(.borderedProminent)
                }
            }
        } else {
            VStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(.largeTitle))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.headline)
                if let description = description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                if let actionTitle = actionTitle, let action = action {
                    Button(actionTitle, action: action)
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
    }
}

/// 封面图：统一圆角与占位样式。
struct CoverImage: View {
    let url: String?
    var size: CGFloat
    var cornerRadius: CGFloat = Layout.coverRadius

    var body: some View {
        RemoteImage(url: url) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            Rectangle()
                .fill(Color(.secondarySystemFill))
                .overlay {
                    Image(systemName: "music.note")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

/// 歌曲行：系统列表里复用。
struct MusicRow: View {
    let music: Music
    var isCurrent: Bool = false
    var isPlaying: Bool = false
    var accessory: AnyView?

    var body: some View {
        HStack(spacing: 12) {
            CoverImage(url: APIConfig.buildMusicCoverURL(musicId: music.id, coverFilePath: music.coverFilePath), size: Layout.coverSize)

            VStack(alignment: .leading, spacing: 2) {
                Text(music.title)
                    .font(.body)
                    .lineLimit(1)
                    .foregroundStyle(isCurrent ? Color.accentColor : .primary)
                Text(music.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if let accessory = accessory {
                accessory
            } else if isCurrent {
                Image(systemName: isPlaying ? "speaker.wave.2.fill" : "speaker.fill")
                    .foregroundStyle(.tint)
                    .font(.caption)
            }
        }
        .contentShape(Rectangle())
    }
}
