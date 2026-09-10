import Foundation

struct TicketCreateRequest: Codable {
    let type: TicketType
    let categoryId: UUID
    let subject: String
    let description: String

    enum CodingKeys: String, CodingKey {
        case type
        case categoryId = "category_id"
        case subject, description
    }
}
struct TicketStatusUpdateRequest: Codable {
    let newStatus: TicketStatus
    let resolutionNote: String?

    enum CodingKeys: String, CodingKey {
        case newStatus = "new_status"
        case resolutionNote = "resolution_note"
    }
}
