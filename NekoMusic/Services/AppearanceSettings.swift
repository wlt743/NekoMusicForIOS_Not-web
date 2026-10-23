import SwiftUI
import UIKit

// MARK: - 主题色

struct ThemeOption: Identifiable, Hashable {
    let id: String
    let name: String
    let color: Color

    static let all: [ThemeOption] = [
        ThemeOption(id: "pink", name: "霓虹粉", color: Color(red: 1.00, green: 0.18, blue: 0.33)),
        ThemeOption(id: "blue", name: "天空蓝", color: Color(red: 0.04, green: 0.52, blue: 1.00)),
        ThemeOption(id: "mint", name: "薄荷绿", color: Color(red: 0.19, green: 0.82, blue: 0.35)),
        ThemeOption(id: "orange", name: "日落橙", color: Color(red: 1.00, green: 0.62, blue: 0.04)),
        ThemeOption(id: "purple", name: "薰衣草", color: Color(red: 0.75, green: 0.35, blue: 0.95)),
        ThemeOption(id: "red", name: "珊瑚红", color: Color(red: 1.00, green: 0.27, blue: 0.23)),
        ThemeOption(id: "graphite", name: "石墨灰", color: Color(red: 0.56, green: 0.56, blue: 0.58)),
    ]

    static let fallback = all[0]
}

// MARK: - 外观设置

/// 主题色与首页壁纸，存在 UserDefaults + Documents。
@MainActor
final class AppearanceSettings: ObservableObject {
    static let shared = AppearanceSettings()

    @Published var themeID: String {
        didSet { UserDefaults.standard.set(themeID, forKey: Keys.theme) }
    }

    @Published private(set) var wallpaperImage: UIImage?

    private enum Keys {
        static let theme = "appearance.themeID"
        static let wallpaper = "appearance.wallpaperFile"
    }

    private var wallpaperFileName: String? {
        get { UserDefaults.standard.string(forKey: Keys.wallpaper) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.wallpaper) }
    }

    var theme: ThemeOption {
        ThemeOption.all.first { $0.id == themeID } ?? .fallback
    }

    var tintColor: Color { theme.color }

    private init() {
        themeID = UserDefaults.standard.string(forKey: Keys.theme) ?? ThemeOption.fallback.id
        wallpaperImage = Self.loadWallpaper(named: UserDefaults.standard.string(forKey: Keys.wallpaper))
    }

    // MARK: 壁纸

    private static var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private static func loadWallpaper(named name: String?) -> UIImage? {
        guard let name = name else { return nil }
        let url = documentsDirectory.appendingPathComponent(name)
        return UIImage(contentsOfFile: url.path)
    }

    func setWallpaper(_ image: UIImage) {
        // 控制体积：长边最多 2000px
        let prepared = Self.downscaled(image, maxSide: 2000)
        guard let data = prepared.jpegData(compressionQuality: 0.9) else { return }

        let name = "home-wallpaper.jpg"
        let url = Self.documentsDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            wallpaperFileName = name
            wallpaperImage = prepared
        } catch {
            NSLog("[NekoAppearance] wallpaper save failed: %@", "\(error)")
        }
    }

    func removeWallpaper() {
        if let name = wallpaperFileName {
            try? FileManager.default.removeItem(at: Self.documentsDirectory.appendingPathComponent(name))
        }
        wallpaperFileName = nil
        wallpaperImage = nil
    }

    private static func downscaled(_ image: UIImage, maxSide: CGFloat) -> UIImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }
        let scale = min(1, maxSide / max(size.width, size.height))
        guard scale < 1 else { return image }

        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
