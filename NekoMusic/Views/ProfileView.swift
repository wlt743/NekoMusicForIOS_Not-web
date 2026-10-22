import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService

    @State private var showLogin = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if authService.isLoggedIn, let user = authService.currentUser {
                        HStack(spacing: 16) {
                            AvatarView(user: user)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.nickname)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                if user.isVip == true {
                                    Label("VIP", systemImage: "crown.fill")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        Button {
                            showLogin = true
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: "person.crop.circle.fill")
                                    .font(.system(.largeTitle))
                                    .foregroundStyle(.secondary)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("点击登录")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    Text("登录后享受更多功能")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 4)
                    }
                }

                if authService.isLoggedIn {
                    Section("音乐") {
                        NavigationLink {
                            FavoritesView()
                        } label: {
                            Label("我的收藏", systemImage: "heart.fill")
                        }

                        NavigationLink {
                            PlaylistsView()
                        } label: {
                            Label("我的歌单", systemImage: "music.note.list")
                        }
                    }
                }

                Section("其他") {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("设置", systemImage: "gearshape")
                    }

                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("关于", systemImage: "info.circle")
                    }
                }

                if authService.isLoggedIn {
                    Section {
                        Button("退出登录", role: .destructive) {
                            authService.logout()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("我的")
        }
        .sheet(isPresented: $showLogin) {
            LoginView()
        }
    }
}

private struct AvatarView: View {
    let user: UserData

    var body: some View {
        RemoteImage(url: APIConfig.userAvatarURL(id: user.id)) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            Circle()
                .fill(Color(.secondarySystemFill))
                .overlay {
                    Text(String(user.nickname.prefix(1)).uppercased())
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
        }
        .frame(width: 60, height: 60)
        .clipShape(Circle())
    }
}

// MARK: - 设置

struct SettingsView: View {
    @EnvironmentObject var authService: AuthService

    @State private var showChangePassword = false
    @State private var oldPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var alertMessage = ""
    @State private var showAlert = false

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    var body: some View {
        List {
            if authService.isLoggedIn {
                Section("账户") {
                    Button("修改密码") {
                        showChangePassword = true
                    }
                }
            }

            Section("信息") {
                LabeledContent("版本", value: appVersion)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .alert("修改密码", isPresented: $showChangePassword) {
            SecureField("当前密码", text: $oldPassword)
            SecureField("新密码", text: $newPassword)
            SecureField("确认新密码", text: $confirmPassword)
            Button("确认") {
                Task { await changePassword() }
            }
            Button("取消", role: .cancel) {
                clearPasswordFields()
            }
        }
        .alert(alertMessage, isPresented: $showAlert) {
            Button("确定") {}
        }
    }

    private func changePassword() async {
        guard newPassword == confirmPassword else {
            alertMessage = "两次输入的密码不一致"
            showAlert = true
            return
        }

        guard newPassword.count >= 6 else {
            alertMessage = "新密码至少 6 位"
            showAlert = true
            return
        }

        do {
            let response = try await authService.changePassword(
                oldPassword: oldPassword,
                newPassword: newPassword
            )
            alertMessage = response.message
            showAlert = true
            if response.success {
                clearPasswordFields()
            }
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    private func clearPasswordFields() {
        oldPassword = ""
        newPassword = ""
        confirmPassword = ""
    }
}

// MARK: - 关于

struct AboutView: View {
    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "music.note.house.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.tint)

                    Text("NekoMusic")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("版本 \(appVersion)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("一款简洁优雅的音乐播放器")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            }

            Section {
                LabeledContent("开发者", value: "Neko Team")
                LabeledContent("平台", value: "iOS")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
    }
}
