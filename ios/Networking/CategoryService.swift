import Foundation

struct CategoryService {
    static let shared = CategoryService()

    func listCategories() async throws -> [Category] {
        try await APIClient.shared.request(path: "/categories", method: .get)
    }

    func createCategory(name: String, description: String?, teamId: UUID?) async throws -> Category {
        struct Body: Encodable {
            let name: String
            let description: String?
            let teamId: UUID?
            enum CodingKeys: String, CodingKey {
                case name, description
                case teamId = "team_id"
            }
        }
        return try await APIClient.shared.request(
            path: "/categories", method: .post,
            body: Body(name: name, description: description, teamId: teamId)
        )
    }

    /// Backend'de DELETE ucu yok, "silme" is_active=false ile yapilir (soft delete).
    /// Boylece o kategorideki gecmis kayitlar bozulmaz.
    func updateCategory(
        id: UUID, name: String? = nil, description: String? = nil,
        isActive: Bool? = nil, teamId: UUID?? = nil
    ) async throws -> Category {
        struct Body: Encodable {
            let name: String?
            let description: String?
            let isActive: Bool?
            let teamId: UUID?
            enum CodingKeys: String, CodingKey {
                case name, description
                case isActive = "is_active"
                case teamId = "team_id"
            }
        }
        // teamId: UUID?? -> disaridan "hic gonderme" ile "nil gonder" ayrimi icin.
        // Burada basitlestirip dogrudan degeri aliyoruz.
        let resolvedTeamId = teamId.flatMap { $0 }
        return try await APIClient.shared.request(
            path: "/categories/\(id.uuidString)", method: .patch,
            body: Body(name: name, description: description, isActive: isActive, teamId: resolvedTeamId)
        )
    }
}
