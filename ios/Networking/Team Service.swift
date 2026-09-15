import Foundation

struct TeamService {
    static let shared = TeamService()

    func listTeams() async throws -> [Team] {
        try await APIClient.shared.request(path: "/teams", method: .get)
    }

    func createTeam(name: String, description: String?) async throws -> Team {
        let body = TeamCreateRequest(name: name, description: description)
        return try await APIClient.shared.request(path: "/teams", method: .post, body: body)
    }

    func listMembers(teamId: UUID) async throws -> [TeamMember] {
        try await APIClient.shared.request(
            path: "/teams/\(teamId.uuidString)/members", method: .get
        )
    }

    func addMember(teamId: UUID, userId: UUID) async throws -> TeamMember {
        let body = TeamMemberAssignRequest(userId: userId)
        return try await APIClient.shared.request(
            path: "/teams/\(teamId.uuidString)/members", method: .post, body: body
        )
    }

    /// 204 No Content dondugu icin govdesiz istek
    func removeMember(teamId: UUID, userId: UUID) async throws {
        try await APIClient.shared.requestVoid(
            path: "/teams/\(teamId.uuidString)/members/\(userId.uuidString)", method: .delete
        )
    }

    func deleteTeam(id: UUID) async throws {
        try await APIClient.shared.requestVoid(path: "/teams/\(id.uuidString)", method: .delete)
    }

    /// Bir kategoriyi bir ekibe baglar (teamId: nil ile baglantiyi kaldirir)
    func assignCategory(categoryId: UUID, teamId: UUID?) async throws {
        struct Body: Encodable {
            let teamId: UUID?
            enum CodingKeys: String, CodingKey { case teamId = "team_id" }
        }
        let _: Category = try await APIClient.shared.request(
            path: "/categories/\(categoryId.uuidString)", method: .patch, body: Body(teamId: teamId)
        )
    }
}
