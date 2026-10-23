import SwiftUI
import UIKit

/// 系统分享面板的 SwiftUI 封装（最右「更多」用）
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}

private struct ShareChannel: Identifiable {
    let id: String
    let name: String
    let icon: String
    let color: Color
    let scheme: String
}

struct SharePanelView: View {
    let text: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var showSystemShare = false
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var copiedToast = false

    private let channels: [ShareChannel] = [
        ShareChannel(id: "wechat", name: "微信", icon: "message.fill", color: Color(red: 0.15, green: 0.78, blue: 0.25), scheme: "weixin://"),
        ShareChannel(id: "moments", name: "朋友圈", icon: "camera.fill", color: Color(red: 0.15, green: 0.78, blue: 0.25), scheme: "weixin://"),
        ShareChannel(id: "qq", name: "QQ", icon: "person.2.fill", color: Color(red: 0.11, green: 0.55, blue: 0.95), scheme: "mqq://"),
        ShareChannel(id: "qzone", name: "QQ空间", icon: "star.fill", color: Color(red: 0.98, green: 0.75, blue: 0.15), scheme: "mqq://"),
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(.tertiaryLabel))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            Text("分享")
                .font(.headline)
                .padding(.top, 14)

            LazyVGrid(columns: columns, spacing: 22) {
                ForEach(channels) { channel in
                    channelButton(channel)
                }

                actionButton(title: "复制链接", icon: "link", color: .gray) {
                    UIPasteboard.general.string = text
                    copiedToast = true
                }

                actionButton(title: "更多", icon: "ellipsis", color: .gray) {
                    showSystemShare = true
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 22)

            Spacer(minLength: 12)

            Button {
                dismiss()
            } label: {
                Text("取消")
                    .font(.body)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .buttonStyle(.plain)
            .background(Color(.secondarySystemGroupedBackground))
        }
        .presentationDetents([.height(330)])
        .presentationDragIndicator(.hidden)
        .overlay(alignment: .bottom) {
            if copiedToast {
                Text("链接已复制")
                    .font(.footnote)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.75), in: Capsule())
                    .padding(.bottom, 64)
                    .transition(.opacity)
            }
        }
        .onChange(of: copiedToast) { value in
            guard value else { return }
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                copiedToast = false
            }
        }
        .alert("提示", isPresented: $showAlert) {
            Button("确定") {}
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showSystemShare) {
            ActivityView(items: [text])
        }
    }

    // MARK: - 按钮

    private func channelButton(_ channel: ShareChannel) -> some View {
        Button {
            UIPasteboard.general.string = text
            if let url = URL(string: channel.scheme), UIApplication.shared.canOpenURL(url) {
                openURL(url)
            } else {
                alertMessage = "没有安装\(channel.name)，内容已复制到剪贴板"
                showAlert = true
            }
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(channel.color)
                        .frame(width: 54, height: 54)
                    Image(systemName: channel.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text(channel.name)
                    .font(.caption2)
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }

    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color(.secondarySystemFill))
                        .frame(width: 54, height: 54)
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(color)
                }
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}
