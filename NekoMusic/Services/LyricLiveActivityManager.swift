import ActivityKit
import Foundation

/// 管理锁屏歌词实时活动（iOS 16.1+）
@available(iOS 16.1, *)
@MainActor
final class LyricLiveActivityManager {
    static let shared = LyricLiveActivityManager()

    private var activity: Activity<LyricActivityAttributes>?
    private var lastState: LyricActivityAttributes.ContentState?

    private init() {}

    func start(title: String, artist: String) {
        guard #available(iOS 16.1, *) else { return }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard activity == nil else { return }

        let state = LyricActivityAttributes.ContentState(
            previous: "",
            current: "正在载入歌词…",
            next: "",
            isPlaying: true
        )

        do {
            activity = try Activity.request(
                attributes: LyricActivityAttributes(title: title, artist: artist),
                contentState: state,
                pushType: nil
            )
            lastState = state
        } catch {
            NSLog("[NekoLive] request failed: %@", "\(error)")
        }
    }

    func update(previous: String, current: String, next: String, isPlaying: Bool) {
        guard #available(iOS 16.1, *) else { return }
        guard let activity = activity else { return }

        let state = LyricActivityAttributes.ContentState(
            previous: previous,
            current: current,
            next: next,
            isPlaying: isPlaying
        )

        // 内容没变就不打扰系统
        guard state != lastState else { return }
        lastState = state

        Task {
            await activity.update(using: state)
        }
    }

    func end() {
        guard #available(iOS 16.1, *) else { return }
        guard let activity = activity else { return }
        self.activity = nil
        lastState = nil
        Task {
            if #available(iOS 16.2, *) {
                await activity.end(nil, dismissalPolicy: .immediate)
            } else {
                await activity.end(dismissalPolicy: .immediate)
            }
        }
    }
}
