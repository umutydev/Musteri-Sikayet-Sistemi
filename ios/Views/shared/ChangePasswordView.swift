import SwiftUI

struct ChangePasswordView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isSubmitting = false
    @State private var didSucceed = false

    private var isValid: Bool {
        !currentPassword.isEmpty
            && newPassword.count >= 8
            && newPassword == confirmPassword
    }

    var body: some View {
        NavigationStack {
            Form {
                if didSucceed {
                    Section {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Şifreniz başarıyla değiştirildi.")
                        }
                    }
                } else {
                    Section("Mevcut Şifre") {
                        SecureField("Mevcut şifreniz", text: $currentPassword)
                    }

                    Section("Yeni Şifre") {
                        SecureField("En az 8 karakter", text: $newPassword)
                        SecureField("Yeni şifre (tekrar)", text: $confirmPassword)

                        if !newPassword.isEmpty {
                            Text("\(newPassword.count)/8 karakter")
                                .font(.caption)
                                .foregroundStyle(newPassword.count >= 8 ? .green : .secondary)
                        }
                        if !confirmPassword.isEmpty && newPassword != confirmPassword {
                            Text("Şifreler eşleşmiyor")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }

                    if let error = auth.lastError {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        if isSubmitting {
                            ProgressView().frame(maxWidth: .infinity)
                        } else {
                            Text("Şifreyi Değiştir").frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!isValid || isSubmitting)
                }
            }
            .navigationTitle("Şifre Değiştir")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(didSucceed ? "Kapat" : "Vazgeç") { dismiss() }
                }
            }
        }
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        didSucceed = await auth.changePassword(current: currentPassword, new: newPassword)
        if didSucceed {
            try? await Task.sleep(for: .seconds(1.5))
            dismiss()
        }
    }
}
