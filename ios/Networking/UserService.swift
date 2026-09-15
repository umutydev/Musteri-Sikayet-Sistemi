import Foundation

struct UserService {
    static let shared = UserService()

    func listUsers(role: UserRole? = nil, isActive: Bool? = nil, search: String? = nil) async throws -> [UserDetail] {
        var items: [URLQueryItem] = [.init(name: "page_size", value: "100")]
        if let role { items.append(.init(name: "role", value: role.rawValue)) }
        if let isActive { items.append(.init(name: "is_active", value: String(isActive))) }
        if let search, !search.isEmpty { items.append(.init(name: "search", value: search)) }

        return try await APIClient.shared.request(path: "/users", method: .get, queryItems: items)
    }

    func createUser(_ request: UserCreateRequest) async throws -> UserDetail {
        try await APIClient.shared.request(path: "/users", method: .post, body: request)
    }

    func updateUser(id: UUID, request: UserUpdateRequest) async throws -> UserDetail {
        try await APIClient.shared.request(
            path: "/users/\(id.uuidString)", method: .patch, body: request
        )
    }

    /// Aktiflik durumunu tersine cevirir (aktif -> pasif, pasif -> aktif)
    func toggleActive(user: UserDetail) async throws -> UserDetail {
        try await updateUser(id: user.id, request: UserUpdateRequest(isActive: !user.isActive))
    }
}
