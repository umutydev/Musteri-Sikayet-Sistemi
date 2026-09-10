import Foundation

struct User: Codable, Identifiable {
    let id: UUID
    let fullName: String
    let email: String
    let role: UserRole

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case email
        case role
    }
}

enum UserRole: String, Codable {
    case customer
    case agent
    case admin
}


