import Foundation

struct User: Codable, Identifiable {
    let id: Int
    let username: String
    let email: String
    let createdAt: String
    let isVip: Bool?
    let vipExpiresAt: String?
}

struct LoginRequest: Codable {
    let username: String
    let password: String
}

struct RegisterRequest: Codable {
    let username: String
    let password: String
    let email: String
    let verificationCode: String
}

struct LoginResponse: Codable {
    let success: Bool
    let message: String
    let data: LoginData?
}

struct LoginData: Codable {
    let user: UserData
    let token: String
}

struct UserData: Codable {
    let id: Int
    let username: String
    let email: String
    let createdAt: String
    let isVip: Bool?
    let vipExpiresAt: String?
}

struct RegisterResponse: Codable {
    let success: Bool
    let message: String
    let data: [String: String]?
}

struct VerificationResponse: Codable {
    let success: Bool
    let message: String
}

struct UpdatePasswordRequest: Codable {
    let oldPassword: String
    let newPassword: String
}

struct UpdatePasswordResponse: Codable {
    let success: Bool
    let message: String
}

struct ResetPasswordRequest: Codable {
    let email: String
    let code: String
    let newPassword: String
}

struct ResetPasswordResponse: Codable {
    let success: Bool
    let message: String
}
