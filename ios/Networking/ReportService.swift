import Foundation

struct ReportService {
    static let shared = ReportService()

    func summary() async throws -> ReportSummary {
        try await APIClient.shared.request(path: "/reports/summary", method: .get)
    }

    func agentPerformance() async throws -> [AgentPerformance] {
        try await APIClient.shared.request(path: "/reports/agent-performance", method: .get)
    }
}
