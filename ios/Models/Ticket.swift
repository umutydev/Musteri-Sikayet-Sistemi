import Foundation
import SwiftUI

enum TicketStatus: String, Codable, CaseIterable {
    case new
    case inReview = "in_review"
    case pendingInfo = "pending_info"
    case resolved
    case rejected
    case closed

    var displayName: String {
        switch self {
        case .new: return "Yeni"
        case .inReview: return "İnceleniyor"
        case .pendingInfo: return "Ek Bilgi Bekleniyor"
        case .resolved: return "Çözüldü"
        case .rejected: return "Reddedildi"
        case .closed: return "Kapatıldı"
        }
    }

    var color: Color {
        switch self {
        case .new: return .gray
        case .inReview: return .blue
        case .pendingInfo: return .orange
        case .resolved: return .green
        case .rejected: return .red
        case .closed: return Color(.darkGray)
        }
    }
}

enum TicketType: String, Codable, CaseIterable {
    case request
    case complaint

    var displayName: String {
        switch self {
        case .request: return "Talep"
        case .complaint: return "Şikayet"
        }
    }
}

enum TicketPriority: String, Codable, CaseIterable {
    case low, medium, high

    var displayName: String {
        switch self {
        case .low: return "Düşük"
        case .medium: return "Orta"
        case .high: return "Yüksek"
        }
    }
}

struct Ticket: Codable, Identifiable {
    let id: UUID
    let referenceNo: String
    let type: TicketType
    let subject: String
    let description: String
    let status: TicketStatus
    let priority: TicketPriority
    let categoryId: UUID
    let assignedTo: UUID?
    let createdAt: Date
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case referenceNo = "reference_no"
        case type, subject, description, status, priority
        case categoryId = "category_id"
        case assignedTo = "assigned_to"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
