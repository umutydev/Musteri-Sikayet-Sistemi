import SwiftUI

/// Iki adimli sifre sifirlama: once e-posta, sonra kod + yeni sifre.
struct ForgotPasswordView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var code = ""
    @State private var newPassword = ""
    @State private var step = 1
    @State private var isSubmitting = false
    @State private var infoMessage: String?
    @State private var didSucceed = false

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
                                Image(systemName: didSucceed ? "checkmark" : "lock.rotation")
                                    .font(.system(size: 30))
                                    .foregroundStyle(.white)
                            )
                            .padding(.top, 24)

                        Text(didSucceed ? "Şifreniz Güncellendi" : "Şifremi Unuttum")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(AppTheme.navy)

                        if didSucceed {
                            Text("Yeni şifrenizle giriş yapabilirsiniz.")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)

                            Button("Giriş Ekranına Dön") { dismiss() }
                                .font(.system(size: 17, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(AppTheme.navy)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else if step == 1 {
                            emailStep
                        } else {
                            codeStep
                        }

                        if let infoMessage {
                            Text(infoMessage)
                                .font(.system(size: 14))
                                .foregroundStyle(AppTheme.primary)
                                .multilineTextAlignment(.center)
                                .padding(12)
                                .frame(maxWidth: .infinity)
                                .background(AppTheme.primary.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        if let error = auth.lastError {
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(24)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .padding(16)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
            }
        }
    }

    private var emailStep: some View {
        VStack(spacing: 18) {
            Text("Hesabınıza ait e-posta adresini girin, size bir doğrulama kodu gönderelim.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                Text("E-posta Adresi")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.navy)
                HStack(spacing: 12) {
                    Image(systemName: "envelope").foregroundStyle(.secondary)
                    TextField("name@company.com", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                }
                .padding(16)
                .background(AppTheme.inputBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button {
                Task { await requestCode() }
            } label: {
                Group {
                    if isSubmitting { ProgressView().tint(.white) }
                    else { Text("Kod Gönder").font(.system(size: 17, weight: .semibold)) }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(email.contains("@") ? AppTheme.navy : Color.gray.opacity(0.3))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!email.contains("@") || isSubmitting)
        }
    }

    private var codeStep: some View {
        VStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Doğrulama Kodu")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.navy)
                TextField("6 haneli kod", text: $code)
                    .keyboardType(.numberPad)
                    .padding(16)
                    .background(AppTheme.inputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Yeni Şifre")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.navy)
                SecureField("En az 8 karakter", text: $newPassword)
                    .padding(16)
                    .background(AppTheme.inputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Text("\(newPassword.count)/8 karakter")
                    .font(.caption)
                    .foregroundStyle(newPassword.count >= 8 ? .green : .secondary)
            }

            Button {
                Task { await submitReset() }
            } label: {
                Group {
                    if isSubmitting { ProgressView().tint(.white) }
                    else { Text("Şifreyi Değiştir").font(.system(size: 17, weight: .semibold)) }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(isCodeStepValid ? AppTheme.navy : Color.gray.opacity(0.3))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!isCodeStepValid || isSubmitting)

            Button("Kodu tekrar gönder") {
                Task { await requestCode() }
            }
            .font(.system(size: 14))
            .foregroundStyle(AppTheme.primary)
        }
    }

    private var isCodeStepValid: Bool {
        code.count == 6 && newPassword.count >= 8
    }

    private func requestCode() async {
        isSubmitting = true
        defer { isSubmitting = false }

        let debugCode = await auth.requestPasswordReset(email: email)
        step = 2

        // E-posta servisi entegre edilene kadar kod ekranda gosteriliyor.
        // Production'da backend debug_code dondurmez, bu satir devre disi kalir.
        if let debugCode {
            infoMessage = "Geliştirme modu — kodunuz: \(debugCode)"
            code = debugCode
        } else {
            infoMessage = "Eğer bu e-posta kayıtlıysa, size bir kod gönderildi."
        }
    }

    private func submitReset() async {
        isSubmitting = true
        defer { isSubmitting = false }
        infoMessage = nil
        didSucceed = await auth.resetPassword(email: email, code: code, newPassword: newPassword)
    }
}
