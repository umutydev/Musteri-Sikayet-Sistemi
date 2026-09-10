import SwiftUI

struct CreateTicketView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var type: TicketType = .complaint
    @State private var categories: [Category] = []
    @State private var selectedCategory: Category?
    @State private var subject = ""
    @State private var description = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var createdRef: String?

    private var isFormValid: Bool {
        selectedCategory != nil && subject.count >= 5 && description.count >= 20
    }

    /// Stepper'ın hangi adımda olduğunu forma göre hesaplar
    private var currentStep: Int {
        if description.count >= 20 { return 3 }
        if selectedCategory != nil && subject.count >= 5 { return 2 }
        return 1
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Yeni Şikayet Oluştur")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(AppTheme.navy)
                            Text("Lütfen sorununuzla ilgili detayları sağlayın, böylece hızlıca çözebiliriz.")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                        }

                        VStack(alignment: .leading, spacing: 20) {
                            StepIndicator(currentStep: currentStep)

                            // Başvuru türü
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Başvuru Türü")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(AppTheme.navy)
                                HStack(spacing: 24) {
                                    ForEach(TicketType.allCases, id: \.self) { t in
                                        Button {
                                            type = t
                                        } label: {
                                            HStack(spacing: 8) {
                                                Image(systemName: type == t ? "largecircle.fill.circle" : "circle")
                                                    .foregroundStyle(type == t ? AppTheme.primary : .secondary)
                                                Text(t.displayName)
                                                    .font(.system(size: 17))
                                                    .foregroundStyle(AppTheme.navy)
                                            }
                                        }
                                    }
                                }
                            }

                            // Konu
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Konu")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(AppTheme.navy)
                                TextField("Sorunu kısaca açıklayın", text: $subject)
                                    .padding(16)
                                    .background(AppTheme.inputBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            // Kategori
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Kategori")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(AppTheme.navy)
                                Menu {
                                    ForEach(categories) { c in
                                        Button(c.name) { selectedCategory = c }
                                    }
                                } label: {
                                    HStack {
                                        Text(selectedCategory?.name ?? "Kategori seçin")
                                            .foregroundStyle(selectedCategory == nil ? .secondary : AppTheme.navy)
                                        Spacer()
                                        Image(systemName: "chevron.down").foregroundStyle(.secondary)
                                    }
                                    .padding(16)
                                    .background(AppTheme.inputBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }

                            // Açıklama
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Açıklama")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(AppTheme.navy)
                                TextEditor(text: $description)
                                    .frame(minHeight: 130)
                                    .padding(10)
                                    .scrollContentBackground(.hidden)
                                    .background(AppTheme.inputBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                Text("En az 20 karakter (\(description.count)/20)")
                                    .font(.caption)
                                    .foregroundStyle(description.count >= 20 ? .green : .secondary)
                            }

                            // Dosya ekleme alanı (görsel — backend hazır olunca aktifleşecek)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Dosya/Fotoğraf Ekle")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(AppTheme.navy)
                                VStack(spacing: 8) {
                                    Image(systemName: "icloud.and.arrow.up")
                                        .font(.system(size: 32))
                                        .foregroundStyle(AppTheme.primary)
                                    Text("Dosya Yükle")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(AppTheme.primary)
                                    Text("PNG, JPG, PDF (Maks. 10MB)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 28)
                                .background(AppTheme.inputBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                                        .foregroundStyle(Color.gray.opacity(0.4))
                                )
                            }

                            if let errorMessage {
                                Text(errorMessage).font(.footnote).foregroundStyle(.red)
                            }
                            if let createdRef {
                                Text("Kaydınız oluşturuldu: \(createdRef)")
                                    .font(.footnote.bold())
                                    .foregroundStyle(.green)
                            }

                            Button {
                                Task { await submit() }
                            } label: {
                                Group {
                                    if isSubmitting { ProgressView().tint(.white) }
                                    else { Text("Gönder").font(.system(size: 17, weight: .semibold)) }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(AppTheme.navy)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(!isFormValid || isSubmitting)
                            .opacity(isFormValid ? 1 : 0.6)
                        }
                        .padding(20)
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .padding(16)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
            }
            .task {
                categories = (try? await CategoryService.shared.listCategories()) ?? []
            }
        }
    }

    private func submit() async {
        guard let category = selectedCategory else { return }
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            let req = TicketCreateRequest(type: type, categoryId: category.id, subject: subject, description: description)
            let ticket = try await TicketService.shared.createTicket(req)
            createdRef = ticket.referenceNo
            try? await Task.sleep(for: .seconds(1))
            dismiss()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Bir hata oluştu."
        }
    }
}

/// Tasarımdaki 1-2-3 adım göstergesi
private struct StepIndicator: View {
    let currentStep: Int

    var body: some View {
        HStack(spacing: 0) {
            ForEach(1...3, id: \.self) { step in
                Circle()
                    .fill(step <= currentStep ? AppTheme.navy : AppTheme.inputBackground)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text("\(step)")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(step <= currentStep ? .white : AppTheme.navy)
                    )
                if step < 3 {
                    Rectangle()
                        .fill(step < currentStep ? AppTheme.navy : Color.gray.opacity(0.2))
                        .frame(height: 3)
                }
            }
        }
    }
}
