//
//  ReportSummary.swift
//  SikayetApp
//
//  Created by Umut on 17.09.2026.
//


import Foundation

/// Backend'deki SummaryOut semasiyla eslesir.
/// Hesaplamalar SQL tarafinda yapilir - istemci yalnizca hazir sonuclari gosterir.
struct ReportSummary: Codable {
    let totalTickets: Int
    let openTickets: Int
    let closedTickets: Int
    let unassignedTickets: Int
    let avgResolutionDays: Double?
    let statusBreakdown: [StatusBreakdown]
    let categoryBreakdown: [CategoryBreakdown]

    enum CodingKeys: String, CodingKey {
        case totalTickets = "total_tickets"
        case openTickets = "open_tickets"
        case closedTickets = "closed_tickets"
        case unassignedTickets = "unassigned_tickets"
        case avgResolutionDays = "avg_resolution_days"
        case statusBreakdown = "status_breakdown"
        case categoryBreakdown = "category_breakdown"
    }
}

struct StatusBreakdown: Codable, Identifiable {
    let status: String
    let count: Int

    var id: String { status }

    /// Backend'den gelen kodu (orn. "in_review") TicketStatus'e cevirip
    /// Turkce etiketini ve rengini alir. Boylece etiketler tek yerden yonetilir.
    var ticketStatus: TicketStatus? { TicketStatus(rawValue: status) }
}

struct CategoryBreakdown: Codable, Identifiable {
    let category: String
    let count: Int

    var id: String { category }
}

struct AgentPerformance: Codable, Identifiable {
    let agentId: UUID
    let agentName: String
    let assignedCount: Int
    let closedCount: Int
    let avgResolutionDays: Double?

    var id: UUID { agentId }

    enum CodingKeys: String, CodingKey {
        case agentId = "agent_id"
        case agentName = "agent_name"
        case assignedCount = "assigned_count"
        case closedCount = "closed_count"
        case avgResolutionDays = "avg_resolution_days"
    }
}