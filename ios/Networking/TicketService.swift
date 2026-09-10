import Foundation

struct TicketService {
    static let shared = TicketService()

    func createTicket(_ req: TicketCreateRequest) async throws -> Ticket {
        try await APIClient.shared.request(path: "/tickets", method: .post, body: req)
    }

    func listTickets(status: TicketStatus? = nil, pool: Bool = false, pageSize: Int = 50) async throws -> [Ticket] {
        var items: [URLQueryItem] = [.init(name: "page_size", value: String(pageSize))]
        if let status { items.append(.init(name: "status", value: status.rawValue)) }
        if pool { items.append(.init(name: "pool", value: "true")) }
        return try await APIClient.shared.request(path: "/tickets", method: .get, queryItems: items)
    }

    func getTicket(id: UUID) async throws -> Ticket {
        try await APIClient.shared.request(path: "/tickets/\(id.uuidString)", method: .get)
    }

    func assignTicket(id: UUID) async throws -> Ticket {
        try await APIClient.shared.request(path: "/tickets/\(id.uuidString)/assign", method: .post)
    }

    func updateStatus(id: UUID, newStatus: TicketStatus, resolutionNote: String? = nil) async throws -> Ticket {
        let body = TicketStatusUpdateRequest(newStatus: newStatus, resolutionNote: resolutionNote)
        return try await APIClient.shared.request(path: "/tickets/\(id.uuidString)/status", method: .patch, body: body)
    }

    func addNote(ticketId: UUID, content: String, isInternal: Bool) async throws -> TicketNote {
        let body = TicketNoteCreateRequest(content: content, isInternal: isInternal)
        return try await APIClient.shared.request(path: "/tickets/\(ticketId.uuidString)/notes", method: .post, body: body)
    }

    func listNotes(ticketId: UUID) async throws -> [TicketNote] {
        try await APIClient.shared.request(path: "/tickets/\(ticketId.uuidString)/notes", method: .get)
    }
}
