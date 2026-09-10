import SwiftUI

struct AdminOverviewView: View {
    @State private var newCount = 0
    @State private var inReviewCount = 0
    @State private var resolvedCount = 0
    @State private var urgentTickets: [Ticket] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        if isLoading {
                            ProgressView().padding(.top, 60)
                        } else {
                            AdminStatCard(title: "ATAMA BEKLEYEN", value: "\(newCount)",
                                          icon: "exclamationmark.triangle.fill",
                                          tint: Color(red: 0.85, green: 0.2, blue: 0.2))

                            AdminStatCard(title: "İNCELENEN", value: "\(inReviewCount)",
                                          icon: "eye.fill",
                                          tint: Color(red: 0.1, green: 0.6, blue: 0.75))

                            AdminStatCard(title: "ÇÖZÜLEN", value: "\(resolvedCount)",
                                          icon: "checkmark.circle.fill",
                                          tint: Color(red: 0.05, green: 0.55, blue: 0.35))

                            // Acil müdahale
                            VStack(alignment: .leading, spacing: 14) {
                                Text("Acil Müdahale Gerekiyor")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(AppTheme.navy)

                                if urgentTickets.isEmpty {
                                    Text("Bekleyen acil kayıt yok.")
                                        .font(.system(size: 15))
                                        .foregroundStyle(.secondary)
                                } else {
                                    ForEach(urgentTickets.prefix(3)) { t in
                                        NavigationLink(value: t.id) {
                                            TicketRowView(ticket: t)
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

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        let newOnes = (try? await TicketService.shared.listTickets(status: .new, pageSize: 200)) ?? []
        let inReview = (try? await TicketService.shared.listTickets(status: .inReview, pageSize: 200)) ?? []
        let resolved = (try? await TicketService.shared.listTickets(status: .resolved, pageSize: 200)) ?? []
        newCount = newOnes.count
        inReviewCount = inReview.count
        resolvedCount = resolved.count
        urgentTickets = newOnes.filter { $0.priority == .high }
        if urgentTickets.isEmpty { urgentTickets = newOnes }
    }
}

private struct AdminStatCard: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundStyle(AppTheme.navy)
            }
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(tint)
                .frame(width: 56, height: 56)
                .background(tint.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
