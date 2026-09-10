import Foundation

struct RegisterRequest: Codable {
    let fullName: String
    let email: String
    let phone: String?
    let password: String

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case email, phone, password
    }
}

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct RefreshRequest: Codable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

struct TokenResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String
    let user: User

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case user
    }
}
