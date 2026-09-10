import SwiftUI

struct CustomerHomeView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var tickets: [Ticket] = []
    @State private var isLoading = true
    @State private var showCreateSheet = false

    private var activeCount: Int {
        tickets.filter { [.new, .inReview, .pendingInfo].contains($0.status) }.count
    }
    private var resolvedCount: Int {
        tickets.filter { $0.status == .resolved }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Başlık
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Merhaba, Size nasıl yardımcı olabiliriz?")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(AppTheme.primary)
                            Text("Sorunlarınızı hızlı ve şeffaf bir şekilde çözmek için buradayız.")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 8)

                        // Ana aksiyon butonu
                        Button {
                            showCreateSheet = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "plus.circle.fill").font(.system(size: 20))
                                Text("Yeni Şikayet Oluştur").font(.system(size: 17, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(AppTheme.navy)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        // Özet kartları
                        StatRow(
                            title: "Aktif Şikayetlerim",
                            value: "\(activeCount)",
                            subtitle: "İşlem bekleyen",
                            icon: "clipboard.fill",
                            valueColor: AppTheme.primary
                        )

                        StatRow(
                            title: "Çözülenler",
                            value: "\(resolvedCount)",
                            subtitle: "Son 30 gün",
                            icon: "checkmark.circle.fill",
                            valueColor: Color(red: 0.05, green: 0.45, blue: 0.35)
                        )

                        // Son aktiviteler
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Son Aktiviteler")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(AppTheme.navy)

                            if isLoading {
                                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
                            } else if tickets.isEmpty {
                                Text("Henüz bir kaydınız yok.")
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.vertical, 20)
                            } else {
                                ForEach(tickets.prefix(3)) { ticket in
                                    NavigationLink(value: ticket.id) {
                                        TicketRowView(ticket: ticket)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(16)
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(16)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: UUID.self) { TicketDetailView(ticketId: $0) }
            .sheet(isPresented: $showCreateSheet) {
                CreateTicketView()
            }
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        tickets = (try? await TicketService.shared.listTickets()) ?? []
    }
}

/// Ana sayfadaki geniş özet kartı (tasarımdaki "Aktif Şikayetlerim / 2 / İşlem bekleyen" kutusu)
private struct StatRow: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let valueColor: Color

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.navy)
                Text(value)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(valueColor)
                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(valueColor)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
