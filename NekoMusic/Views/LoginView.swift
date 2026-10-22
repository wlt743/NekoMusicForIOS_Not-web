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
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.house.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.tint)

                        Text("NekoMusic")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .listRowBackground(Color.clear)
                }

                Section {
                    Picker("模式", selection: $isLoginMode) {
                        Text("登录").tag(true)
                        Text("注册").tag(false)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                }

                Section {
                    if !isLoginMode {
                        TextField("昵称", text: $nickname)
                            .textContentType(.username)
                            .textInputAutocapitalization(.never)
                    }

                    TextField("邮箱", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("密码", text: $password)
                        .textContentType(isLoginMode ? .password : .newPassword)

                    if !isLoginMode {
                        HStack {
                            TextField("邮箱验证码", text: $verificationCode)
                                .keyboardType(.numberPad)

                            Button {
                                Task { await requestCaptcha() }
                            } label: {
                                if isSendingCode {
                                    ProgressView()
                                } else {
                                    Text("发送验证码")
                                }
                            }
                            .buttonStyle(.borderless)
                            .disabled(isSendingCode)
                        }
                    }
                } footer: {
                    if !isLoginMode {
                        Text("发送验证码前需要完成滑块验证")
                    } else {
                        Text("使用注册邮箱和密码登录")
                    }
                }

                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                            } else {
                                Text(isLoginMode ? "登录" : "注册")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isLoading)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle(isLoginMode ? "登录" : "注册")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
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
                .presentationDetents([.medium, .large])
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

    // MARK: - 操作

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
