import Foundation

/// Senin "Mesajlar" (müşteri tarafı) ve "Dahili Notlar" (temsilci tarafı)
/// ekranlarındaki tek tek mesaj/not baloncuklarının veri karşılığı.
struct TicketNote: Codable, Identifiable {
    let id: UUID
    let authorId: UUID
    let content: String
    let isInternal: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case authorId = "author_id"
        case content
        case isInternal = "is_internal"
        case createdAt = "created_at"
    }
}

struct TicketNoteCreateRequest: Codable {
    let content: String
    let isInternal: Bool

    enum CodingKeys: String, CodingKey {
        case content
        case isInternal = "is_internal"
    }
}
