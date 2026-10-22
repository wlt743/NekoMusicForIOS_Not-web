import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var isLoginMode = true
    @State private var nickname = ""
    @State private var email = ""
    @State private var password = ""
    @State private var verificationCode = ""
    @State private var captchaPassToken: String?
    @State private var showCaptcha = false
    @State private var isLoading = false
    @State private var isSendingCode = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showCodeSent = false

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
                        // 昵称（注册）
                        if !isLoginMode {
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.gray)
                                    .frame(width: 24)
                                TextField("昵称", text: $nickname)
                                    .textContentType(.username)
                                    .autocapitalization(.none)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }

                        // 邮箱
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

                        // 密码
                        HStack {
                            Image(systemName: "lock.fill")
                                .foregroundColor(.gray)
                                .frame(width: 24)
                            SecureField("密码", text: $password)
                                .textContentType(isLoginMode ? .password : .newPassword)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)

                        // 验证码（注册）
                        if !isLoginMode {
                            HStack {
                                Image(systemName: "number")
                                    .foregroundColor(.gray)
                                    .frame(width: 24)
                                TextField("邮箱验证码", text: $verificationCode)
                                    .keyboardType(.numberPad)

                                Button {
                                    Task { await requestCaptcha() }
                                } label: {
                                    if isSendingCode {
                                        ProgressView()
                                    } else {
                                        Text("发送验证码")
                                            .font(.caption)
                                            .foregroundColor(.pink)
                                    }
                                }
                                .disabled(isSendingCode)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)

                            Text("发送验证码前需要完成滑块验证")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
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

                    if isLoginMode {
                        Text("使用注册邮箱和密码登录")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

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
            .sheet(isPresented: $showCaptcha) {
                SliderCaptchaView(
                    onSuccess: { passToken in
                        showCaptcha = false
                        captchaPassToken = passToken
                        Task { await sendVerificationCode() }
                    },
                    onCancel: {
                        showCaptcha = false
                    }
                )
            }
            .alert("提示", isPresented: $showError) {
                Button("确定") {}
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("验证码已发送", isPresented: $showCodeSent) {
                Button("确定") {}
            } message: {
                Text("请查收邮箱并填写 6 位验证码")
            }
        }
    }

    // MARK: - Actions

    private func requestCaptcha() async {
        guard !email.isEmpty else {
            show(message: "请先填写邮箱")
            return
        }
        guard email.contains("@") else {
            show(message: "邮箱格式不正确")
            return
        }
        if nickname.isEmpty {
            nickname = String(email.split(separator: "@").first ?? "用户")
        }
        await MainActor.run { showCaptcha = true }
    }

    private func sendVerificationCode() async {
        guard let passToken = captchaPassToken else { return }
        await MainActor.run { isSendingCode = true }

        do {
            let response = try await authService.sendVerificationCode(
                email: email,
                nickname: nickname,
                captchaPassToken: passToken
            )
            await MainActor.run {
                isSendingCode = false
                if response.success {
                    showCodeSent = true
                } else {
                    errorMessage = response.message
                    showError = true
                }
            }
        } catch {
            await MainActor.run {
                isSendingCode = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func submit() async {
        guard !email.isEmpty, !password.isEmpty else {
            show(message: "请填写邮箱和密码")
            return
        }

        if !isLoginMode {
            guard !nickname.isEmpty else {
                show(message: "请填写昵称")
                return
            }
            guard !verificationCode.isEmpty else {
                show(message: "请填写邮箱验证码")
                return
            }
        }

        await MainActor.run { isLoading = true }

        do {
            if isLoginMode {
                let response = try await authService.login(email: email, password: password)
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
                let response = try await authService.register(
                    nickname: nickname,
                    password: password,
                    email: email,
                    verificationCode: verificationCode
                )
                await MainActor.run {
                    isLoading = false
                    if response.success {
                        errorMessage = "注册成功，请使用邮箱和密码登录"
                        showError = true
                        isLoginMode = true
                        password = ""
                        verificationCode = ""
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

    private func show(message: String) {
        errorMessage = message
        showError = true
    }
}
