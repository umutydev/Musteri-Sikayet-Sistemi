import SwiftUI

/// NOT: Backend'de /notifications endpoint'i henüz yok (Sprint 5).
/// UI hazır — servis eklendiğinde load() içi doldurulacak.
struct NotificationsView: View {
    @State private var selectedFilter = 0

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Çözümlerinizden haberdar olun.")
                            .font(.system(size: 16))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            FilterChip(title: "Tüm Bildirimler", isSelected: selectedFilter == 0) { selectedFilter = 0 }
                            FilterChip(title: "Durum Güncellemeleri", isSelected: selectedFilter == 1) { selectedFilter = 1 }
                            FilterChip(title: "Mesajlar", isSelected: selectedFilter == 2) { selectedFilter = 2 }
                        }
                        .padding(.horizontal, 16)
                    }
                    .padding(.vertical, 16)

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
                }
            }
            .navigationTitle("Bildirimler")
        }
    }
}
