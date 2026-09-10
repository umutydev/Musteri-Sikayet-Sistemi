import Foundation
import Security

/// Token'ları Keychain'de saklar — UserDefaults'ta ASLA şifre/token tutulmaz.
actor TokenStore {
    static let shared = TokenStore()
    private let service = "com.banka.sikayetapp"

    private(set) var accessToken: String?
    private(set) var refreshToken: String?

    private init() {
        accessToken = read(key: "access_token")
        refreshToken = read(key: "refresh_token")
    }

    func save(accessToken: String, refreshToken: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        write(key: "access_token", value: accessToken)
        write(key: "refresh_token", value: refreshToken)
    }

    func clear() {
        accessToken = nil
        refreshToken = nil
        delete(key: "access_token")
        delete(key: "refresh_token")
    }

    private func write(key: String, value: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key]
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = Data(value.utf8)
        SecItemAdd(item as CFDictionary, nil)
    }

    private func read(key: String) -> String? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func delete(key: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key]
        SecItemDelete(query as CFDictionary)
    }
}
