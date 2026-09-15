import SwiftUI

/// Ekip detayi: uyeler ve sorumlu olunan kategoriler yonetilir.
struct TeamDetailView: View {
    let team: Team
    let onChanged: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var members: [TeamMember] = []
    @State private var allAgents: [UserDetail] = []
    @State private var categories: [Category] = []
    @State private var isLoading = true
    @State private var showAddMember = false
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?

    private var availableAgents: [UserDetail] {
        let memberIds = Set(members.map(\.id))
        return allAgents.filter { !memberIds.contains($0.id) && $0.role != .customer }
    }

    private var teamCategories: [Category] {
        categories.filter { $0.teamId == team.id }
    }

    private var unassignedCategories: [Category] {
        categories.filter { $0.teamId == nil }
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    headerCard
                    membersCard
                    categoriesCard
                    deleteButton
                }
                .padding(16)
            }
        }
        .navigationTitle(team.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddMember) {
            AddMemberSheet(agents: availableAgents) { userId in
                Task { await addMember(userId) }
            }
        }
        .confirmationDialog(
            "Bu ekibi silmek istediğinize emin misiniz? Üyeler ve kategoriler ekipten çıkarılacak.",
            isPresented: $showDeleteConfirm, titleVisibility: .visible
        ) {
            Button("Ekibi Sil", role: .destructive) { Task { await deleteTeam() } }
            Button("Vazgeç", role: .cancel) {}
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let description = team.description {
                Text(description)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 20) {
                statItem(value: "\(members.count)", label: "Üye")
                statItem(value: "\(team.activeTicketCount)", label: "Aktif Vaka")
                statItem(value: "\(teamCategories.count)", label: "Kategori")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.navy)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
    }

    private var membersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Üyeler")
                    .font(.system(size: 19, weight: .bold))
                    .foregroundStyle(AppTheme.navy)
                Spacer()
                Button {
                    showAddMember = true
                } label: {
                    Label("Ekle", systemImage: "person.badge.plus")
                        .font(.system(size: 14, weight: .semibold))
                }
                .disabled(availableAgents.isEmpty)
            }

            if isLoading {
                ProgressView().frame(maxWidth: .infinity)
            } else if members.isEmpty {
                Text("Bu ekipte henüz üye yok.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(members) { member in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(AppTheme.primary.opacity(0.15))
                            .frame(width: 40, height: 40)
                            .overlay(
                                Text(initials(member.fullName))
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(AppTheme.primary)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(member.fullName)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(AppTheme.navy)
                            Text(member.email)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button {
                            Task { await removeMember(member.id) }
                        } label: {
                            Image(systemName: "minus.circle")
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(12)
                    .background(AppTheme.inputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var categoriesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sorumlu Olunan Kategoriler")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(AppTheme.navy)

            Text("Bu kategorilerdeki yeni kayıtlar ekibin havuzuna düşer.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            if teamCategories.isEmpty {
                Text("Henüz kategori atanmamış.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(teamCategories) { category in
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(AppTheme.primary)
                        Text(category.name)
                            .font(.system(size: 16))
                            .foregroundStyle(AppTheme.navy)
                        Spacer()
                        Button {
                            Task { await assignCategory(category.id, to: nil) }
                        } label: {
                            Image(systemName: "minus.circle").foregroundStyle(.red)
                        }
                    }
                    .padding(12)
                    .background(AppTheme.inputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            if !unassignedCategories.isEmpty {
                Menu {
                    ForEach(unassignedCategories) { category in
                        Button(category.name) {
                            Task { await assignCategory(category.id, to: team.id) }
                        }
                    }
                } label: {
                    Label("Kategori Ata", systemImage: "plus.circle")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppTheme.inputBackground)
                        .foregroundStyle(AppTheme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            if let errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.red)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var deleteButton: some View {
        Button {
            showDeleteConfirm = true
        } label: {
            Text("Ekibi Sil")
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.red.opacity(0.1))
                .foregroundStyle(.red)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        async let m = TeamService.shared.listMembers(teamId: team.id)
        async let a = UserService.shared.listUsers(role: .agent)
        async let c = CategoryService.shared.listCategories()

        members = (try? await m) ?? []
        allAgents = (try? await a) ?? []
        categories = (try? await c) ?? []
    }

    private func addMember(_ userId: UUID) async {
        do {
            _ = try await TeamService.shared.addMember(teamId: team.id, userId: userId)
            await load()
            onChanged()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Üye eklenemedi."
        }
    }

    private func removeMember(_ userId: UUID) async {
        do {
            try await TeamService.shared.removeMember(teamId: team.id, userId: userId)
            await load()
            onChanged()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Üye çıkarılamadı."
        }
    }

    private func assignCategory(_ categoryId: UUID, to teamId: UUID?) async {
        do {
            try await TeamService.shared.assignCategory(categoryId: categoryId, teamId: teamId)
            await load()
            onChanged()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Kategori atanamadı."
        }
    }

    private func deleteTeam() async {
        do {
            try await TeamService.shared.deleteTeam(id: team.id)
            onChanged()
            dismiss()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Ekip silinemedi."
        }
    }

    private func initials(_ name: String) -> String {
        name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
    }
}

// MARK: - Üye ekleme

private struct AddMemberSheet: View {
    let agents: [UserDetail]
    let onSelect: (UUID) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if agents.isEmpty {
                    VStack(spacing: 10) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text("Eklenebilecek temsilci yok.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    List(agents) { agent in
                        Button {
                            onSelect(agent.id)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(agent.fullName)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(AppTheme.navy)
                                Text(agent.email)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Üye Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
            }
        }
    }
}
