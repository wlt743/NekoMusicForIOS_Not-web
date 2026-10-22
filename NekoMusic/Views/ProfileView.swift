import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showLogin = false
    @State private var showSettings = false
    
    var body: some View {
        NavigationView {
            List {
                // User Info Section
                Section {
                    if authService.isLoggedIn, let user = authService.currentUser {
                        HStack(spacing: 16) {
                            RemoteImage(url: APIConfig.userAvatarURL(id: user.id)) { image in
                                image.resizable().aspectRatio(contentMode: .fill)
                            } placeholder: {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.pink, .purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(
                                        Text(String(user.username.prefix(1)).uppercased())
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    )
                            }
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.username)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                Text(user.email)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if user.isVip == true {
                                    HStack(spacing: 4) {
                                        Image(systemName: "crown.fill")
                                            .font(.caption2)
                                        Text("VIP")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                    }
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.1))
                                    .cornerRadius(10)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    } else {
                        Button {
                            showLogin = true
                        } label: {
                            HStack(spacing: 16) {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: "person.fill")
                                            .font(.title2)
                                            .foregroundColor(.gray)
                                    )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("点击登录")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    Text("登录后享受更多功能")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // Features Section
                if authService.isLoggedIn {
                    Section {
                        NavigationLink {
                            FavoritesView()
                        } label: {
                            Label("我的收藏", systemImage: "heart.fill")
                                .foregroundColor(.pink)
                        }
                        
                        NavigationLink {
                            PlaylistsView()
                        } label: {
                            Label("我的歌单", systemImage: "music.note.list")
                                .foregroundColor(.purple)
                        }
                    } header: {
                        Text("音乐")
                    }
                }
                
                // Settings Section
                Section {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("设置", systemImage: "gearshape.fill")
                    }
                    
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label("关于", systemImage: "info.circle.fill")
                    }
                } header: {
                    Text("其他")
                }
                
                // Logout
                if authService.isLoggedIn {
                    Section {
                        Button(role: .destructive) {
                            authService.logout()
                        } label: {
                            HStack {
                                Spacer()
                                Text("退出登录")
                                Spacer()
                            }
                        }
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

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showChangePassword = false
    @State private var oldPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var alertMessage = ""
    @State private var showAlert = false
    
    var body: some View {
        List {
            Section {
                if authService.isLoggedIn {
                    Button("修改密码") {
                        showChangePassword = true
                    }
                }
            } header: {
                Text("账户")
            }
            
            Section {
                HStack {
                    Text("版本")
                    Spacer()
                    Text("1.0.1")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("信息")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("设置")
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
            alertMessage = "新密码至少6位"
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

// MARK: - About View
struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 16) {
                    Image(systemName: "music.note.house.fill")
                        .font(.system(size: 64))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.pink, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Text("NekoMusic")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("版本 1.0.1")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("一款简洁优雅的音乐播放器")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            }
            
            Section {
                HStack {
                    Text("开发者")
                    Spacer()
                    Text("Neko Team")
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("平台")
                    Spacer()
                    Text("iOS")
                        .foregroundColor(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("关于")
    }
}
