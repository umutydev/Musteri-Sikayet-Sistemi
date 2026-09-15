import Foundation

/// Admin listelerinde donen detayli kullanici bilgisi.
/// Mevcut User modelinden ayri tutuldu cunku backend daha fazla alan donuyor
/// (phone, is_active, created_at) ve bunlar yalnizca admin ekranlarinda gerekli.
struct UserDetail: Codable, Identifiable {
    let id: UUID
    let fullName: String
    let email: String
    let phone: String?
    let role: UserRole
    let isActive: Bool
    let teamId: UUID?
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case email, phone, role
        case isActive = "is_active"
        case teamId = "team_id"
        case createdAt = "created_at"
    }
}
struct UserCreateRequest: Codable {
    let fullName: String
    let email: String
    let phone: String?
    let password: String
    let role: UserRole

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case email, phone, password, role
    }
}

/// Tum alanlar opsiyonel - yalnizca degistirilmek istenenler gonderilir.
struct UserUpdateRequest: Codable {
    var fullName: String?
    var phone: String?
    var role: UserRole?
    var isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case phone, role
        case isActive = "is_active"
    }
}

extension UserRole {
    var displayName: String {
        switch self {
        case .customer: return "Müşteri"
        case .agent: return "Temsilci"
        case .admin: return "Yönetici"
        }
    }
}
