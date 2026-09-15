import Foundation
import SwiftUI

/// Destek ekibi. Backend'deki TeamDetailOut semasiyla eslesir.
/// memberCount ve activeTicketCount backend tarafinda hesaplanip gonderilir -
/// istemcide ayrica sorgu yapmaya gerek kalmaz.
struct Team: Codable, Identifiable {
    let id: UUID
    let name: String
    let description: String?
    let isActive: Bool
    let memberCount: Int
    let activeTicketCount: Int
    let categoryNames: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, description
        case isActive = "is_active"
        case memberCount = "member_count"
        case activeTicketCount = "active_ticket_count"
        case categoryNames = "category_names"
    }

    /// Is yuku arttikca uyari rengi
    var workloadColor: Color {
        if activeTicketCount >= 20 { return .red }
        if activeTicketCount >= 10 { return .orange }
        return AppTheme.primary
    }
}

struct TeamMember: Codable, Identifiable {
    let id: UUID
    let fullName: String
    let email: String
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case fullName = "full_name"
        case email
        case isActive = "is_active"
    }
}

struct TeamCreateRequest: Codable {
    let name: String
    let description: String?
}

struct TeamMemberAssignRequest: Codable {
    let userId: UUID

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
    }
}
