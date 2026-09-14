import Foundation

/// Backend'deki NotificationOut semasiyla birebir eslesir.
/// NOT: Tip adi "AppNotification" - Swift'in kendi "Notification" tipiyle
/// (NotificationCenter'daki) cakismamasi icin bilerek farkli isimlendirildi.
struct AppNotification: Codable, Identifiable {
    let id: UUID
    let ticketId: UUID?
    let message: String
    let isRead: Bool
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case ticketId = "ticket_id"
        case message
        case isRead = "is_read"
        case createdAt = "created_at"
    }
}

struct UnreadCountResponse: Codable {
    let unreadCount: Int

    enum CodingKeys: String, CodingKey {
        case unreadCount = "unread_count"
    }
}
