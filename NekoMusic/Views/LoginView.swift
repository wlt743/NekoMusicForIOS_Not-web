import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    
    @State private var isLoginMode = true
    @State private var username = ""
    @State private var password = ""
    @State private var email = ""
    @State private var verificationCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 32) {
                    // Logo
                    VStack(spacing: 12) {
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
                            .font(.largeTitle)
                            .fontWeight(.bold)
                    }
                    .padding(.top, 40)
                    
                    // Mode Picker
                    Picker("", selection: $isLoginMode) {
                        Text("登录").tag(true)
                        Text("注册").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 32)
                    
                    // Form Fields
                    VStack(spacing: 16) {
                        // Username
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                                .frame(width: 24)
                            TextField("用户名", text: $username)
                                .textContentType(.username)
                                .autocapitalization(.none)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        // Email (Register only)
                        if !isLoginMode {
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .foregroundColor(.gray)
                                    .frame(width: 24)
                                TextField("邮箱", text: $email)
                                    .textContentType(.emailAddress)
                                    .autocapitalization(.none)
                                    .keyboardType(.emailAddress)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        
                        // Password
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.gray)
                                .frame(width: 24)
                            SecureField("密码", text: $password)
                                .textContentType(.password)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        // Verification Code (Register only)
                        if !isLoginMode {
                            HStack {
                                Image(systemName: "number")
                                    .foregroundColor(.gray)
                                    .frame(width: 24)
                                TextField("验证码", text: $verificationCode)
                                    .keyboardType(.numberPad)
                                
                                Button("发送验证码") {
                                    Task { await sendCode() }
                                }
                                .font(.caption)
                                .foregroundColor(.pink)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    // Submit Button
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(isLoginMode ? "登录" : "注册")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.pink, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading)
                    .padding(.horizontal, 32)
                    
                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
            .alert("提示", isPresented: $showError) {
                Button("确定") {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private func submit() async {
        guard !username.isEmpty, !password.isEmpty else {
            errorMessage = "请填写用户名和密码"
            showError = true
            return
        }
        
        isLoading = true
        
        do {
            if isLoginMode {
                let response = try await authService.login(username: username, password: password)
                await MainActor.run {
                    isLoading = false
                    if response.success {
                        dismiss()
                    } else {
                        errorMessage = response.message
                        showError = true
                    }
                }
            } else {
                guard !email.isEmpty else {
                    errorMessage = "请填写邮箱"
                    showError = true
                    isLoading = false
                    return
                }
                guard !verificationCode.isEmpty else {
                    errorMessage = "请填写验证码"
                    showError = true
                    isLoading = false
                    return
                }
                
                let response = try await authService.register(
                    username: username,
                    password: password,
                    email: email,
                    verificationCode: verificationCode
                )
                await MainActor.run {
                    isLoading = false
                    if response.success {
                        errorMessage = "注册成功，请登录"
                        showError = true
                        isLoginMode = true
                    } else {
                        errorMessage = response.message
                        showError = true
                    }
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
    
    private func sendCode() async {
        guard !email.isEmpty, !username.isEmpty else {
            errorMessage = "请先填写邮箱和用户名"
            showError = true
            return
        }
        
        do {
            let response = try await authService.sendVerificationCode(email: email, username: username)
            await MainActor.run {
                errorMessage = response.message
                showError = true
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
