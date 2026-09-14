import Foundation

struct AttachmentService {
    static let shared = AttachmentService()

    func listAttachments(ticketId: UUID) async throws -> [Attachment] {
        try await APIClient.shared.request(
            path: "/tickets/\(ticketId.uuidString)/attachments", method: .get
        )
    }

    func upload(ticketId: UUID, pending: PendingAttachment) async throws -> Attachment {
        try await APIClient.shared.upload(
            path: "/tickets/\(ticketId.uuidString)/attachments",
            fileName: pending.fileName,
            contentType: pending.contentType,
            data: pending.data
        )
    }

    /// Dosyayi indirir ve gecici bir klasore kaydeder, acilabilir bir URL dondurur.
    func download(ticketId: UUID, attachment: Attachment) async throws -> URL {
        let url = APIConfig.baseURL
            .appendingPathComponent("/tickets/\(ticketId.uuidString)/attachments/\(attachment.id.uuidString)/download")

        var req = URLRequest(url: url)
        if let token = await TokenStore.shared.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw APIError.network(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError.network(URLError(.badServerResponse))
        }
        guard (200...299).contains(http.statusCode) else {
            if http.statusCode == 403 { throw APIError.forbidden("") }
            if http.statusCode == 404 { throw APIError.notFound }
            throw APIError.server("")
        }

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(attachment.fileName)
        try data.write(to: tempURL)
        return tempURL
    }
}
