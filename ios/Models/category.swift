import Foundation

struct Category: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let description: String?
    let isActive: Bool
    let teamId: UUID?

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case isActive = "is_active"
        case teamId = "team_id"
    }
}
