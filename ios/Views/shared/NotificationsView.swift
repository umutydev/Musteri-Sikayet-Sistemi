import SwiftUI

struct NotificationsView: View {
    @State private var notifications: [AppNotification] = []
    @State private var isLoading = true
    @State private var selectedFilter = 0
    @State private var errorMessage: String?

    /// Filtre secimine gore listeyi daraltir.
    /// 0 = Tumu, 1 = Okunmamis, 2 = Okunmus
    private var filtered: [AppNotification] {
        switch selectedFilter {
        case 1: return notifications.filter { !$0.isRead }
        case 2: return notifications.filter { $0.isRead }
        default: return notifications
        }
    }

    private var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    header

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            FilterChip(title: "Tüm Bildirimler", isSelected: selectedFilter == 0) {
                                selectedFilter = 0
                            }
                            FilterChip(title: "Okunmamış (\(unreadCount))", isSelected: selectedFilter == 1) {
                                selectedFilter = 1
                            }
                            FilterChip(title: "Okunmuş", isSelected: selectedFilter == 2) {
                                selectedFilter = 2
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 14)

                    content
                }
            }
            .navigationTitle("Bildirimler")
            .navigationDestination(for: UUID.self) { TicketDetailView(ticketId: $0) }
            .task { await load() }
            .refreshable { await load() }
        }
    }

    // MARK: - Alt bileşenler

    private var header: some View {
        HStack {
            Text("Çözümlerinizden haberdar olun.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
            Spacer()
            if unreadCount > 0 {
                Button {
                    Task { await markAllRead() }
                } label: {
                    Label("Tümünü okundu işaretle", systemImage: "checkmark.circle")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.primary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            Spacer()
            ProgressView()
            Spacer()
        } else if let errorMessage {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)
                Text(errorMessage)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Tekrar Dene") { Task { await load() } }
                    .buttonStyle(.bordered)
            }
            .padding(32)
            Spacer()
        } else if filtered.isEmpty {
            Spacer()
            VStack(spacing: 10) {
                Image(systemName: "bell.slash")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                Text("Henüz bildiriminiz yok.")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filtered) { item in
                        NotificationRow(notification: item) {
                            Task { await open(item) }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Veri işlemleri

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            notifications = try await NotificationService.shared.listNotifications()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Bildirimler yüklenemedi."
        }
    }

    /// Bildirime dokunuldugunda once okundu isaretlenir, sonra ilgili kayda gidilir.
    private func open(_ item: AppNotification) async {
        if !item.isRead {
            _ = try? await NotificationService.shared.markAsRead(id: item.id)
            // Sunucuya tekrar gitmeden yerel listeyi guncelliyoruz - anlik geri bildirim
            if let index = notifications.firstIndex(where: { $0.id == item.id }) {
                let old = notifications[index]
                notifications[index] = AppNotification(
                    id: old.id, ticketId: old.ticketId, message: old.message,
                    isRead: true, createdAt: old.createdAt
                )
            }
        }
    }

    private func markAllRead() async {
        try? await NotificationService.shared.markAllAsRead()
        await load()
    }
}

/// Tek bir bildirim satiri. ticketId varsa ilgili kayda yonlendirir.
private struct NotificationRow: View {
    let notification: AppNotification
    let onTap: () -> Void

    var body: some View {
        Group {
            if let ticketId = notification.ticketId {
                NavigationLink(value: ticketId) {
                    rowContent
                }
                .buttonStyle(.plain)
                .simultaneousGesture(TapGesture().onEnded { onTap() })
            } else {
                rowContent
            }
        }
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(notification.isRead ? Color.gray.opacity(0.15) : AppTheme.primary.opacity(0.15))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "bell.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(notification.isRead ? .secondary : AppTheme.primary)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(notification.message)
                    .font(.system(size: 15, weight: notification.isRead ? .regular : .semibold))
                    .foregroundStyle(AppTheme.navy)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(notification.createdAt, style: .relative)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if !notification.isRead {
                Circle()
                    .fill(AppTheme.primary)
                    .frame(width: 9, height: 9)
                    .padding(.top, 6)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
