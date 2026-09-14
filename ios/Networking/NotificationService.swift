import Foundation

struct NotificationService {
    static let shared = NotificationService()

    func listNotifications(unreadOnly: Bool = false) async throws -> [AppNotification] {
        var items: [URLQueryItem] = [.init(name: "page_size", value: "50")]
        if unreadOnly {
            items.append(.init(name: "unread_only", value: "true"))
        }
        return try await APIClient.shared.request(
            path: "/notifications", method: .get, queryItems: items
        )
    }

    func unreadCount() async throws -> Int {
        let response: UnreadCountResponse = try await APIClient.shared.request(
            path: "/notifications/unread-count", method: .get
        )
        return response.unreadCount
    }

    func markAsRead(id: UUID) async throws -> AppNotification {
        try await APIClient.shared.request(
            path: "/notifications/\(id.uuidString)/read", method: .patch
        )
    }

    func markAllAsRead() async throws {
        let _: UnreadCountResponse = try await APIClient.shared.request(
            path: "/notifications/read-all", method: .patch
        )
    }
}
