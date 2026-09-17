import SwiftUI

struct CategoryManagementView: View {
    @State private var categories: [Category] = []
    @State private var teams: [Team] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showCreateSheet = false
    @State private var editingCategory: Category?

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            content
        }
        .navigationTitle("Sistem Kategorileri")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CategoryFormSheet(category: nil, teams: teams) { Task { await load() } }
        }
        .sheet(item: $editingCategory) { category in
            CategoryFormSheet(category: category, teams: teams) { Task { await load() } }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage {
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundStyle(.orange)
                Text(errorMessage)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Tekrar Dene") { Task { await load() } }
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(32)
        } else if categories.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "folder")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("Henüz kategori oluşturulmamış.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(categories) { category in
                        CategoryRow(
                            category: category,
                            teamName: teamName(for: category),
                            onEdit: { editingCategory = category }
                        )
                    }
                }
                .padding(16)
            }
        }
    }

    private func teamName(for category: Category) -> String? {
        guard let teamId = category.teamId else { return nil }
        return teams.first(where: { $0.id == teamId })?.name
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        async let c = CategoryService.shared.listCategories()
        async let t = TeamService.shared.listTeams()

        do {
            categories = try await c
            teams = (try? await t) ?? []
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Kategoriler yüklenemedi."
        }
    }
}

// MARK: - Kategori satırı

private struct CategoryRow: View {
    let category: Category
    let teamName: String?
    let onEdit: () -> Void

    var body: some View {
        Button {
            onEdit()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(category.isActive ? AppTheme.primary : .secondary)
                    .frame(width: 36, height: 36)
                    .background((category.isActive ? AppTheme.primary : Color.gray).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(category.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.navy)
                        if !category.isActive {
                            Text("Pasif")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.red.opacity(0.12))
                                .foregroundStyle(.red)
                                .clipShape(Capsule())
                        }
                    }

                    if let description = category.description {
                        Text(description)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Text(teamName ?? "Ekip atanmamış")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(teamName == nil ? .orange : AppTheme.primary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
// MARK: - Ekle/Düzenle formu

private struct CategoryFormSheet: View {
    /// nil ise "yeni kategori", doluysa "düzenleme" modu
    let category: Category?
    let teams: [Team]
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var description: String
    @State private var selectedTeamId: UUID?
    @State private var isActive: Bool
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    init(category: Category?, teams: [Team], onSaved: @escaping () -> Void) {
        self.category = category
        self.teams = teams
        self.onSaved = onSaved
        _name = State(initialValue: category?.name ?? "")
        _description = State(initialValue: category?.description ?? "")
        _selectedTeamId = State(initialValue: category?.teamId)
        _isActive = State(initialValue: category?.isActive ?? true)
    }

    private var isEditing: Bool { category != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Kategori Bilgileri") {
                    TextField("Kategori Adı", text: $name)
                    TextField("Açıklama (opsiyonel)", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                }

                Section("Sorumlu Ekip") {
                    Picker("Ekip", selection: $selectedTeamId) {
                        Text("Atanmamış (tüm temsilciler görür)").tag(Optional<UUID>.none)
                        ForEach(teams) { team in
                            Text(team.name).tag(Optional(team.id))
                        }
                    }
                }

                if isEditing {
                    Section {
                        Toggle("Aktif", isOn: $isActive)
                    }
                }

                if let errorMessage {
                    Text(errorMessage).font(.footnote).foregroundStyle(.red)
                }

                Button {
                    Task { await submit() }
                } label: {
                    if isSubmitting {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text(isEditing ? "Kaydet" : "Kategori Oluştur").frame(maxWidth: .infinity)
                    }
                }
                .disabled(name.count < 2 || isSubmitting)
            }
            .navigationTitle(isEditing ? "Kategoriyi Düzenle" : "Yeni Kategori")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
            }
        }
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        do {
            if let category {
                _ = try await CategoryService.shared.updateCategory(
                    id: category.id,
                    name: name,
                    description: description.isEmpty ? nil : description,
                    isActive: isActive,
                    teamId: .some(selectedTeamId)
                )
            } else {
                _ = try await CategoryService.shared.createCategory(
                    name: name,
                    description: description.isEmpty ? nil : description,
                    teamId: selectedTeamId
                )
            }
            onSaved()
            dismiss()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "İşlem başarısız."
        }
    }
}
