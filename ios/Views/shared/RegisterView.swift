import SwiftUI

struct RegisterView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var fullName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var isSubmitting = false

    private var isFormValid: Bool {
        fullName.count >= 2 && email.contains("@") && password.count >= 8
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        Circle()
                            .fill(AppTheme.primary)
                            .frame(width: 72, height: 72)
                            .overlay(
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 30))
                                    .foregroundStyle(.white)
                            )
                            .padding(.top, 24)

                        VStack(spacing: 8) {
                            Text("ResolvePoint")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(AppTheme.primary)
                            Text("Şikayetlerinizi iletmek ve takip etmek için hesabınızı oluşturun.")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }

                        VStack(spacing: 18) {
                            FormField(label: "Ad Soyad", icon: "person", placeholder: "Jane Doe", text: $fullName)

                            FormField(label: "E-posta Adresi", icon: "envelope", placeholder: "jane@example.com", text: $email)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.emailAddress)

                            FormField(label: "Telefon Numarası", icon: "phone", placeholder: "+90 (5xx) 000-0000", text: $phone)
                                .keyboardType(.phonePad)

                            // Şifre (göster/gizle butonlu)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Şifre")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(AppTheme.navy)
                                HStack(spacing: 12) {
                                    Image(systemName: "lock").foregroundStyle(.secondary)
                                    if showPassword {
                                        TextField("••••••••", text: $password)
                                            .textInputAutocapitalization(.never)
                                    } else {
                                        SecureField("••••••••", text: $password)
                                    }
                                    Button {
                                        showPassword.toggle()
                                    } label: {
                                        Image(systemName: showPassword ? "eye.slash" : "eye")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                                .background(AppTheme.inputBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                                Text("En az 8 karakter olmalıdır")
                                    .font(.caption)
                                    .foregroundStyle(password.count >= 8 ? .green : .secondary)
                            }
                        }

                        if let error = auth.lastError {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button {
                            Task { await submit() }
                        } label: {
                            Group {
                                if isSubmitting {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Kayıt Ol").font(.system(size: 17, weight: .semibold))
                                }
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
                    .padding(24)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
            }
        }
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        let ok = await auth.register(
            fullName: fullName, email: email,
            phone: phone.isEmpty ? nil : phone, password: password
        )
        if ok { dismiss() }
    }
}

/// Tekrar eden input alanı yapısı — her seferinde aynı kodu yazmamak için
struct FormField: View {
    let label: String
    let icon: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.navy)
            HStack(spacing: 12) {
                Image(systemName: icon).foregroundStyle(.secondary)
                TextField(placeholder, text: $text)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(AppTheme.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
