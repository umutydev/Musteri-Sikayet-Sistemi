import SwiftUI

/// Kurumsal iletisim bilgileri.
/// Numaraya dokununca arama, e-postaya dokununca mail uygulamasi acilir.
struct ContactSupportView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    header
                    contactCard
                    hoursCard
                    addressCard
                }
                .padding(16)
            }
        }
        .navigationTitle("İletişim")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(spacing: 12) {
            SolviaLogo(size: 64)
            Text("Size yardımcı olmaktan memnuniyet duyarız")
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var contactCard: some View {
        VStack(spacing: 0) {
            ContactRow(
                icon: "phone.fill",
                title: "Müşteri Hizmetleri",
                value: "0850 222 76 58",
                subtitle: "7/24 hizmetinizdeyiz"
            ) {
                openURL(URL(string: "tel:08502227658")!)
            }

            Divider().padding(.leading, 62)

            ContactRow(
                icon: "envelope.fill",
                title: "E-posta",
                value: "destek@solvia.com.tr",
                subtitle: "24 saat içinde yanıt"
            ) {
                openURL(URL(string: "mailto:destek@solvia.com.tr")!)
            }

            Divider().padding(.leading, 62)

            ContactRow(
                icon: "exclamationmark.shield.fill",
                title: "Kayıp / Çalıntı Kart",
                value: "0850 222 76 00",
                subtitle: "Acil hat"
            ) {
                openURL(URL(string: "tel:08502227600")!)
            }
        }
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var hoursCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Çalışma Saatleri", systemImage: "clock.fill")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppTheme.navy)

            HourRow(day: "Hafta içi", hours: "09:00 – 18:00")
            HourRow(day: "Cumartesi", hours: "09:00 – 13:00")
            HourRow(day: "Pazar", hours: "Kapalı")

            Text("Telefon hattımız hafta sonu dahil 7/24 açıktır.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var addressCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Genel Müdürlük", systemImage: "building.2.fill")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(AppTheme.navy)

            Text("Solvia Finans A.Ş.\nMaslak Mah. Büyükdere Cad. No: 245\nSarıyer / İstanbul")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

private struct ContactRow: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundStyle(AppTheme.primary)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.primary.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.navy)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .buttonStyle(.plain)
    }
}

private struct HourRow: View {
    let day: String
    let hours: String

    var body: some View {
        HStack {
            Text(day)
                .font(.system(size: 15))
                .foregroundStyle(AppTheme.navy)
            Spacer()
            Text(hours)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(hours == "Kapalı" ? .secondary : AppTheme.primary)
        }
    }
}
