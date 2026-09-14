import Foundation

/// Backend'deki AttachmentOut semasiyla eslesir.
/// NOT: file_url (diskteki gercek yol) backend tarafindan BILEREK gonderilmiyor.
/// Dosyaya erisim yalnizca /download ucu uzerinden, yetki kontrolu ile yapilir.
struct Attachment: Codable, Identifiable {
    let id: UUID
    let ticketId: UUID
    let fileName: String
    let contentType: String
    let uploadedBy: UUID
    let uploadedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case ticketId = "ticket_id"
        case fileName = "file_name"
        case contentType = "content_type"
        case uploadedBy = "uploaded_by"
        case uploadedAt = "uploaded_at"
    }

    /// Dosya turune gore ikon secer
    var iconName: String {
        if contentType == "application/pdf" { return "doc.text.fill" }
        if contentType.hasPrefix("image/") { return "photo.fill" }
        return "paperclip"
    }
}

/// Yuklenmeye hazir, henuz sunucuya gonderilmemis dosya.
/// Kullanici formda dosya sectiginde bellekte bunlar tutulur.
struct PendingAttachment: Identifiable {
    let id = UUID()
    let fileName: String
    let contentType: String
    let data: Data

    var sizeText: String {
        ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
    }
}
