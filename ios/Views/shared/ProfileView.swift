import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var showLogoutConfirm = false
    @State private var emailNotifications = true
    @State private var smsNotifications = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        // Profil kartı
                        VStack(spacing: 12) {
                            Circle()
                                .fill(AppTheme.primary.opacity(0.15))
                                .frame(width: 96, height: 96)
                                .overlay(
                                    Text(initials)
                                        .font(.system(size: 34, weight: .bold))
                                        .foregroundStyle(AppTheme.primary)
                                )
                            Text(auth.currentUser?.fullName ?? "")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(AppTheme.navy)
                            Text(auth.currentUser?.email ?? "")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                            Text(roleLabel)
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(AppTheme.primary.opacity(0.12))
                                .foregroundStyle(AppTheme.primary)
                                .clipShape(Capsule())
                        }
                        .padding(24)
                        .frame(maxWidth: .infinity)
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 18))

                        SettingsSection(title: "Hesap Ayarları") {
                            SettingsRow(icon: "lock", title: "Şifre Değiştir")
                            SettingsRow(icon: "shield", title: "İki Faktörlü Doğrulama")
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bildirimler")
                                .font(.system(size: 19, weight: .bold))
                                .foregroundStyle(AppTheme.navy)
                                .padding(.bottom, 8)
                            Toggle(isOn: $emailNotifications) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("E-posta Bildirimleri").font(.system(size: 16))
                                    Text("Şikayetlerinize dair güncellemeler")
                                        .font(.system(size: 13)).foregroundStyle(.secondary)
                                }
                            }
                            .tint(AppTheme.primary)
                            Divider().padding(.vertical, 8)
                            Toggle(isOn: $smsNotifications) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("SMS Bildirimleri").font(.system(size: 16))
                                    Text("Acil durum değişiklikleri")
                                        .font(.system(size: 13)).foregroundStyle(.secondary)
                                }
                            }
                            .tint(AppTheme.primary)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16))

                        SettingsSection(title: "Destek") {
                            SettingsRow(icon: "questionmark.circle", title: "Yardım Merkezi ve SSS")
                            SettingsRow(icon: "bubble.left", title: "Destekle İletişime Geç")
                        }

                        Button {
                            showLogoutConfirm = true
                        } label: {
                            Text("Çıkış Yap")
                                .font(.system(size: 17, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.red.opacity(0.1))
                                .foregroundStyle(.red)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Profil")
            .confirmationDialog("Çıkış yapmak istediğinize emin misiniz?", isPresented: $showLogoutConfirm) {
                Button("Çıkış Yap", role: .destructive) { Task { await auth.logout() } }
                Button("Vazgeç", role: .cancel) {}
            }
        }
    }

    private var initials: String {
        let parts = (auth.currentUser?.fullName ?? "").split(separator: " ")
        return parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
    }

    private var roleLabel: String {
        switch auth.currentUser?.role {
        case .customer: return "Müşteri"
        case .agent: return "Temsilci"
        case .admin: return "Yönetici"
        case .none: return ""
        }
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(AppTheme.navy)
                .padding(.bottom, 8)
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct SettingsRow: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(AppTheme.navy)
                .frame(width: 24)
            Text(title).font(.system(size: 16))
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
    }
}
