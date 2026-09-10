import SwiftUI

struct AgentTasksView: View {
    @State private var myTickets: [Ticket] = []
    @State private var poolTickets: [Ticket] = []
    @State private var isLoading = true
    @State private var selectedTab = 0
    @State private var searchText = ""

    private var items: [Ticket] {
        let source = selectedTab == 0 ? myTickets : poolTickets
        guard !searchText.isEmpty else { return source }
        return source.filter {
            $0.subject.localizedCaseInsensitiveContains(searchText) ||
            $0.referenceNo.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Şikayet ID veya anahtar kelime ara...", text: $searchText)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // Sekmeler
                    HStack(spacing: 0) {
                        TabButton(title: "Görevlerim", isSelected: selectedTab == 0) { selectedTab = 0 }
                        TabButton(title: "Atanmamış", isSelected: selectedTab == 1) { selectedTab = 1 }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    ScrollView {
                        LazyVStack(spacing: 14) {
                            if isLoading {
                                ProgressView().padding(.top, 40)
                            } else if items.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "tray").font(.largeTitle).foregroundStyle(.secondary)
                                    Text("Kayıt bulunamadı.").foregroundStyle(.secondary)
                                }
                                .padding(.top, 60)
                            } else {
                                ForEach(items) { t in
                                    if selectedTab == 0 {
                                        NavigationLink(value: t.id) {
                                            TicketRowView(ticket: t)
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        VStack(spacing: 10) {
                                            TicketRowView(ticket: t)
                                            Button {
                                                Task { await assign(t) }
                                            } label: {
                                                Text("Bana Ata")
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 14)
                                                    .background(AppTheme.navy)
                                                    .foregroundStyle(.white)
                                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 20)
                    }
                    .refreshable { await load() }
                }
            }
            .navigationTitle("Görevler")
            .navigationDestination(for: UUID.self) { TicketDetailView(ticketId: $0) }
            .task { await load() }
            .onChange(of: selectedTab) { _, _ in Task { await load() } }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        if selectedTab == 0 {
            myTickets = (try? await TicketService.shared.listTickets(pageSize: 100)) ?? []
        } else {
            poolTickets = (try? await TicketService.shared.listTickets(pool: true, pageSize: 100)) ?? []
        }
    }

    private func assign(_ t: Ticket) async {
        _ = try? await TicketService.shared.assignTicket(id: t.id)
        await load()
    }
}

private struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 17, weight: isSelected ? .bold : .regular))
                    .foregroundStyle(isSelected ? AppTheme.primary : .secondary)
                Rectangle()
                    .fill(isSelected ? AppTheme.primary : Color.clear)
                    .frame(height: 3)
            }
            .frame(maxWidth: .infinity)
        }
    }
}
