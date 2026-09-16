import Foundation
import Combine
import SwiftUI

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published private(set) var currentUser: User?
    @Published private(set) var isLoading = true
    @Published var lastError: String?

    private init() {
        Task { await restoreSession() }
    }

    var isAuthenticated: Bool { currentUser != nil }

    func register(fullName: String, email: String, phone: String?, password: String) async -> Bool {
        do {
            let body = RegisterRequest(fullName: fullName, email: email, phone: phone, password: password)
            let _: User = try await APIClient.shared.request(path: "/auth/register", method: .post, body: body, requiresAuth: false)
            return await login(email: email, password: password)
        } catch {
            lastError = (error as? APIError)?.errorDescription ?? "Kayıt sırasında hata oluştu."
            return false
        }
    }

    func login(email: String, password: String) async -> Bool {
        do {
            let body = LoginRequest(email: email, password: password)
            let res: TokenResponse = try await APIClient.shared.request(path: "/auth/login", method: .post, body: body, requiresAuth: false)
            await TokenStore.shared.save(accessToken: res.accessToken, refreshToken: res.refreshToken)
            currentUser = res.user
            lastError = nil
            return true
        } catch {
            lastError = (error as? APIError)?.errorDescription ?? "Giriş başarısız."
            return false
        }
    }

    func logout() async {
        await TokenStore.shared.clear()
        currentUser = nil
    }

    func refreshAccessToken() async -> Bool {
        guard let refreshToken = await TokenStore.shared.refreshToken else { return false }
        do {
            let body = RefreshRequest(refreshToken: refreshToken)
            let res: TokenResponse = try await APIClient.shared.request(path: "/auth/refresh", method: .post, body: body, requiresAuth: false)
            await TokenStore.shared.save(accessToken: res.accessToken, refreshToken: res.refreshToken)
            currentUser = res.user
            return true
        } catch {
            return false
        }
    }
    /// FR-1.3: Sifirlama kodu ister. Gelistirme ortaminda kodu geri dondurur.
    func requestPasswordReset(email: String) async -> String? {
        do {
            let body = ForgotPasswordRequest(email: email)
            let response: ForgotPasswordResponse = try await APIClient.shared.request(
                path: "/auth/forgot-password", method: .post, body: body, requiresAuth: false
            )
            lastError = nil
            return response.debugCode
        } catch {
            lastError = (error as? APIError)?.errorDescription ?? "İşlem başarısız."
            return nil
        }
    }

    /// FR-1.3: Kodu dogrulayip yeni sifreyi kaydeder.
    func resetPassword(email: String, code: String, newPassword: String) async -> Bool {
        do {
            let body = ResetPasswordRequest(email: email, code: code, newPassword: newPassword)
            let _: User = try await APIClient.shared.request(
                path: "/auth/reset-password", method: .post, body: body, requiresAuth: false
            )
            lastError = nil
            return true
        } catch {
            lastError = (error as? APIError)?.errorDescription ?? "Şifre sıfırlanamadı."
            return false
        }
    }

    private func restoreSession() async {
        defer { isLoading = false }
        guard await TokenStore.shared.accessToken != nil else { return }
        do {
            let user: User = try await APIClient.shared.request(path: "/auth/me", method: .get)
            currentUser = user
        } catch {
            await TokenStore.shared.clear()
        }
    }
}
