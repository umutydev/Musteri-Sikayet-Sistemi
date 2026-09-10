import Foundation

struct CategoryService {
    static let shared = CategoryService()

    func listCategories() async throws -> [Category] {
        try await APIClient.shared.request(path: "/categories", method: .get)
    }

    func createCategory(name: String, description: String?) async throws -> Category {
        struct Body: Encodable { let name: String; let description: String? }
        return try await APIClient.shared.request(path: "/categories", method: .post, body: Body(name: name, description: description))
    }
}
