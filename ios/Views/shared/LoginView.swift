import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var showRegister = false
    @State private var showForgotPassword = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        Spacer(minLength: 60)

                        // Kart
                        VStack(spacing: 20) {
                            // Logo alanı
                            SolviaLogo(size: 88)
                                .padding(.top, 8)

                            VStack(spacing: 6) {
                                Text("Solvia")
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundStyle(AppTheme.navy)
                                Text("Çözüme giden yol")
                                    .font(.system(size: 17))
                                    .foregroundStyle(.secondary)
                            }
                                // E-posta
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("E-posta Adresi")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(AppTheme.navy)

                                    HStack(spacing: 12) {
                                        Image(systemName: "envelope")
                                            .foregroundStyle(.secondary)
                                        TextField("name@company.com", text: $email)
                                            .textInputAutocapitalization(.never)
                                            .keyboardType(.emailAddress)
                                            .autocorrectionDisabled()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 16)
                                    .background(AppTheme.inputBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }

                                // Şifre
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Şifre")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(AppTheme.navy)
                                        Spacer()
                                        Button("Şifremi Unuttum?") { showForgotPassword = true }                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(AppTheme.primary)
                                    }

                                    HStack(spacing: 12) {
                                        Image(systemName: "lock")
                                            .foregroundStyle(.secondary)
                                        SecureField("••••••••", text: $password)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 16)
                                    .background(AppTheme.inputBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }

                            if let error = auth.lastError {
                                Text(error)
                                    .font(.footnote)
                                    .foregroundStyle(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            // Giriş butonu
                            Button {
                                Task { await submit() }
                            } label: {
                                Group {
                                    if isSubmitting {
                                        ProgressView().tint(.white)
                                    } else {
                                        Text("Giriş Yap")
                                            .font(.system(size: 17, weight: .semibold))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(AppTheme.navy)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(email.isEmpty || password.isEmpty || isSubmitting)
                            .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1)

                            // Kayıt ol
                            HStack(spacing: 4) {
                                Text("Hesabın yok mu?")
                                    .foregroundStyle(.secondary)
                                Button("Kayıt ol") { showRegister = true }
                                    .fontWeight(.semibold)
                                    .foregroundStyle(AppTheme.primary)
                            }
                            .font(.system(size: 15))
                            .padding(.top, 4)
                        }
                        .padding(28)
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.05), radius: 20, y: 4)
                        .padding(.horizontal, 20)

                        Spacer(minLength: 40)
                    }
                }
            }
            .sheet(isPresented: $showRegister) { RegisterView() }
            .sheet(isPresented: $showForgotPassword) { ForgotPasswordView() }
        }
    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        _ = await auth.login(email: email, password: password)
    }
}

