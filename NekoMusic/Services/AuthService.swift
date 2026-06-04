import Foundation

class AuthService: ObservableObject {
    static let shared = AuthService()
    private let network = NetworkService.shared
    
    @Published var isLoggedIn: Bool = false
    @Published var currentUser: UserData?
    @Published var token: String?
    
    private let tokenKey = "auth_token"
    private let userKey = "auth_user"
    
    private init() {
        loadSavedSession()
    }
    
    // MARK: - Session Management
    
    private func loadSavedSession() {
        if let savedToken = UserDefaults.standard.string(forKey: tokenKey) {
            self.token = savedToken
            self.isLoggedIn = true
            
            if let userData = UserDefaults.standard.data(forKey: userKey),
               let user = try? JSONDecoder().decode(UserData.self, from: userData) {
                self.currentUser = user
            }
        }
    }
    
    private func saveSession(token: String, user: UserData) {
        UserDefaults.standard.set(token, forKey: tokenKey)
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: userKey)
        }
        self.token = token
        self.currentUser = user
        self.isLoggedIn = true
    }
    
    func logout() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)
        self.token = nil
        self.currentUser = nil
        self.isLoggedIn = false
    }
    
    // MARK: - Auth APIs
    
    func login(username: String, password: String) async throws -> LoginResponse {
        let body = LoginRequest(username: username, password: password)
        let response: LoginResponse = try await network.post(
            url: APIConfig.loginURL(),
            body: body
        )
        
        if response.success, let data = response.data {
            await MainActor.run {
                saveSession(token: data.token, user: data.user)
            }
        }
        
        return response
    }
    
    func register(username: String, password: String, email: String, verificationCode: String) async throws -> RegisterResponse {
        let body = RegisterRequest(
            username: username,
            password: password,
            email: email,
            verificationCode: verificationCode
        )
        let response: RegisterResponse = try await network.post(
            url: APIConfig.registerURL(),
            body: body
        )
        return response
    }
    
    func sendVerificationCode(email: String, username: String) async throws -> VerificationResponse {
        struct VerificationRequest: Codable {
            let email: String
            let username: String
        }
        
        let body = VerificationRequest(email: email, username: username)
        let response: VerificationResponse = try await network.post(
            url: APIConfig.sendVerificationURL(),
            body: body
        )
        return response
    }
    
    func sendResetCode(email: String) async throws -> VerificationResponse {
        struct SendResetCodeRequest: Codable {
            let email: String
        }
        
        let body = SendResetCodeRequest(email: email)
        let response: VerificationResponse = try await network.post(
            url: APIConfig.sendResetCodeURL(),
            body: body
        )
        return response
    }
    
    func resetPassword(email: String, code: String, newPassword: String) async throws -> ResetPasswordResponse {
        let body = ResetPasswordRequest(email: email, code: code, newPassword: newPassword)
        let response: ResetPasswordResponse = try await network.post(
            url: APIConfig.resetPasswordURL(),
            body: body
        )
        return response
    }
    
    func changePassword(oldPassword: String, newPassword: String) async throws -> UpdatePasswordResponse {
        guard let token = token else {
            throw NetworkError.unauthorized
        }
        
        let body = UpdatePasswordRequest(oldPassword: oldPassword, newPassword: newPassword)
        let response: UpdatePasswordResponse = try await network.post(
            url: APIConfig.changePasswordURL(),
            body: body,
            token: "Bearer \(token)"
        )
        return response
    }
}
