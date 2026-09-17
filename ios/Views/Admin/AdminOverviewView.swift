import SwiftUI

/// Yonetici genel bakis ekrani.
/// Veriler /reports/summary ve /reports/agent-performance uclarindan gelir;
/// hesaplamalar SQL tarafinda yapildigi icin istemci yalnizca gosterir.
struct AdminOverviewView: View {
    @State private var summary: ReportSummary?
    @State private var agents: [AgentPerformance] = []
    @State private var urgentTickets: [Ticket] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        if isLoading {
                            ProgressView().padding(.top, 60)
                        } else if let errorMessage {
                            errorView(errorMessage)
                        } else if let summary {
                            statCards(summary)
                            if !summary.statusBreakdown.isEmpty {
                                statusCard(summary)
                            }
                            if !summary.categoryBreakdown.isEmpty {
                                categoryCard(summary)
                            }
                            if !agents.isEmpty {
                                agentCard
                            }
                            urgentCard
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Genel Bakış")
            .navigationDestination(for: UUID.self) { TicketDetailView(ticketId: $0) }
            .task { await load() }
            .refreshable { await load() }
        }
    }

    // MARK: - Kartlar

    private func statCards(_ summary: ReportSummary) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                CompactStat(
                    title: "TOPLAM",
                    value: "\(summary.totalTickets)",
                    icon: "tray.full.fill",
                    tint: AppTheme.primary
                )
                CompactStat(
                    title: "AÇIK",
                    value: "\(summary.openTickets)",
                    icon: "clock.fill",
                    tint: .orange
                )
            }
            HStack(spacing: 12) {
                CompactStat(
                    title: "ATAMA BEKLEYEN",
                    value: "\(summary.unassignedTickets)",
                    icon: "exclamationmark.triangle.fill",
                    tint: .red
                )
                CompactStat(
                    title: "ORT. ÇÖZÜM",
                    value: summary.avgResolutionDays.map { "\($0) gün" } ?? "—",
                    icon: "timer",
                    tint: Color(red: 0.05, green: 0.55, blue: 0.4)
                )
            }
        }
    }

    /// Durum dagilimi - her durum icin oransal cubuk
    private func statusCard(_ summary: ReportSummary) -> some View {
        let maxCount = summary.statusBreakdown.map(\.count).max() ?? 1

        return VStack(alignment: .leading, spacing: 14) {
            Text("Durum Dağılımı")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(AppTheme.navy)

            ForEach(summary.statusBreakdown) { item in
                let color = item.ticketStatus?.color ?? .gray
                let label = item.ticketStatus?.displayName ?? item.status

                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(label)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppTheme.navy)
                        Spacer()
                        Text("\(item.count)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(color)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.12))
                            Capsule()
                                .fill(color)
                                .frame(width: geo.size.width * ratio(item.count, maxCount))
                        }
                    }
                    .frame(height: 8)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func categoryCard(_ summary: ReportSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kategori Dağılımı")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(AppTheme.navy)

            ForEach(summary.categoryBreakdown) { item in
                HStack {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.primary)
                    Text(item.category)
                        .font(.system(size: 15))
                        .foregroundStyle(AppTheme.navy)
                    Spacer()
                    Text("\(item.count)")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var agentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Temsilci Performansı")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(AppTheme.navy)

            ForEach(agents) { agent in
                HStack(spacing: 12) {
                    Circle()
                        .fill(AppTheme.primary.opacity(0.15))
                        .frame(width: 38, height: 38)
                        .overlay(
                            Text(initials(agent.agentName))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(AppTheme.primary)
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text(agent.agentName)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(AppTheme.navy)
                        Text("\(agent.assignedCount) atanan · \(agent.closedCount) çözülen")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if let days = agent.avgResolutionDays {
                        VStack(spacing: 0) {
                            Text("\(days)")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(AppTheme.navy)
                            Text("gün")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(AppTheme.inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var urgentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Acil Müdahale Gerekiyor")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(AppTheme.navy)

            if urgentTickets.isEmpty {
                Text("Atama bekleyen kayıt yok.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(urgentTickets.prefix(3)) { ticket in
                    NavigationLink(value: ticket.id) {
                        TicketRowView(ticket: ticket)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Tekrar Dene") { Task { await load() } }
                .buttonStyle(.bordered)
        }
        .padding(32)
    }

    // MARK: - Yardımcılar

    private func ratio(_ value: Int, _ max: Int) -> CGFloat {
        max > 0 ? CGFloat(value) / CGFloat(max) : 0
    }

    private func initials(_ name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let s = ReportService.shared.summary()
            async let a = ReportService.shared.agentPerformance()
            async let t = TicketService.shared.listTickets(status: .new, pageSize: 20)

            summary = try await s
            agents = (try? await a) ?? []
            urgentTickets = (try? await t) ?? []
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Raporlar yüklenemedi."
        }
    }
}

// MARK: - Küçük istatistik kartı

private struct CompactStat: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: icon)
                    .font(.system(size: 15))
                    .foregroundStyle(tint)
            }
            Text(value)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AppTheme.navy)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
