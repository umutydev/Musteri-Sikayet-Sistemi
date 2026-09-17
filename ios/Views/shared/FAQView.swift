import SwiftUI

/// Statik SSS sayfasi. Sorular uygulama icinde tanimli - backend gerektirmez.
/// Icerik degisirse bu dosyadaki dizi guncellenir.
struct FAQView: View {
    private let items: [FAQItem] = [
        FAQItem(
            question: "Talep ile şikayet arasındaki fark nedir?",
            answer: "Talep, bir hizmet veya bilgi isteğinizi iletmek için kullanılır (örneğin limit artırımı). Şikayet ise yaşadığınız bir sorunu bildirmek içindir (örneğin hesabınızdan hatalı çekim)."
        ),
        FAQItem(
            question: "Başvurum ne kadar sürede sonuçlanır?",
            answer: "Başvurular öncelik durumuna göre değerlendirilir. Ortalama çözüm süremiz 2-3 iş günüdür. Karmaşık vakalarda süre uzayabilir; bu durumda sizden ek bilgi talep edilebilir."
        ),
        FAQItem(
            question: "Başvurumun durumunu nasıl takip ederim?",
            answer: "\"Şikayetlerim\" sekmesinden tüm kayıtlarınızı görebilirsiniz. Bir kayda dokunduğunuzda süreç akışını, temsilci yanıtlarını ve ekli belgeleri görüntüleyebilirsiniz."
        ),
        FAQItem(
            question: "Başvuru durumları ne anlama geliyor?",
            answer: "Yeni: Başvurunuz alındı, henüz bir temsilciye atanmadı.\nİnceleniyor: Bir temsilci başvurunuzu incelemeye başladı.\nEk Bilgi Bekleniyor: Sizden ek belge veya açıklama bekleniyor.\nÇözüldü: Başvurunuz olumlu sonuçlandı.\nReddedildi: Başvurunuz değerlendirildi ancak olumlu sonuçlanmadı."
        ),
        FAQItem(
            question: "Başvuruma belge ekleyebilir miyim?",
            answer: "Evet. Yeni başvuru oluştururken en fazla 5 adet dosya ekleyebilirsiniz. PNG, JPG ve PDF formatları desteklenir; her dosya en fazla 10 MB olabilir."
        ),
        FAQItem(
            question: "Şifremi unuttum, ne yapmalıyım?",
            answer: "Giriş ekranındaki \"Şifremi Unuttum?\" bağlantısını kullanın. Kayıtlı e-posta adresinize 6 haneli bir doğrulama kodu gönderilir. Kod 15 dakika geçerlidir."
        ),
        FAQItem(
            question: "Bildirimleri nasıl yönetirim?",
            answer: "Profil sayfasındaki Bildirimler bölümünden e-posta ve SMS tercihlerinizi düzenleyebilirsiniz. Başvurunuzla ilgili durum değişikliklerinde uygulama içi bildirim de alırsınız."
        ),
    ]

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 12) {
                    ForEach(items) { item in
                        FAQRow(item: item)
                    }
                }
                .padding(16)
            }
        }
        .navigationTitle("Yardım Merkezi")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FAQItem: Identifiable {
    let id = UUID()
    let question: String
    let answer: String
}

/// Acilir-kapanir soru karti
private struct FAQRow: View {
    let item: FAQItem
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Text(item.question)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.navy)
                        .multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppTheme.primary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(item.answer)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
        }
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
