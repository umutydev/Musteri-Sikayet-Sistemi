import SwiftUI

struct MyTicketsView: View {
    @State private var tickets: [Ticket] = []
    @State private var isLoading = true
    @State private var selectedFilter: TicketStatus?
    @State private var searchText = ""

    private var filtered: [Ticket] {
        var r = tickets
        if let f = selectedFilter { r = r.filter { $0.status == f } }
        if !searchText.isEmpty {
            r = r.filter {
                $0.subject.localizedCaseInsensitiveContains(searchText) ||
                $0.referenceNo.localizedCaseInsensitiveContains(searchText)
            }
        }
        return r
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Arama kutusu
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("ID veya Konu ile Ara...", text: $searchText)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // Filtre çipleri
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            FilterChip(title: "Tümü", isSelected: selectedFilter == nil) {
                                selectedFilter = nil
                            }
                            ForEach([TicketStatus.new, .inReview, .pendingInfo, .resolved, .rejected], id: \.self) { s in
                                FilterChip(title: s.displayName, isSelected: selectedFilter == s) {
                                    selectedFilter = s
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 14)

                    // Liste
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            if isLoading {
                                ProgressView().padding(.top, 40)
                            } else if filtered.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "tray")
                                        .font(.largeTitle)
                                        .foregroundStyle(.secondary)
                                    Text("Kayıt bulunamadı.")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.top, 60)
                            } else {
                                ForEach(filtered) { t in
                                    NavigationLink(value: t.id) {
                                        TicketRowView(ticket: t)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                    }
                    .refreshable { await load() }
                }
            }
            .navigationTitle("Şikayetlerim")
            .navigationDestination(for: UUID.self) { TicketDetailView(ticketId: $0) }
            .task { await load() }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        tickets = (try? await TicketService.shared.listTickets(pageSize: 100)) ?? []
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(isSelected ? AppTheme.navy : AppTheme.card)
                .foregroundStyle(isSelected ? .white : AppTheme.navy)
                .clipShape(Capsule())
                .overlay(
                    Capsule().stroke(isSelected ? Color.clear : Color.gray.opacity(0.25), lineWidth: 1)
                )
        }
    }
}
