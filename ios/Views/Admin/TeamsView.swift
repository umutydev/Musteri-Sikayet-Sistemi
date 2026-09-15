import SwiftUI

/// Destek ekipleri listesi. Her kart: ekip adi, aciklama, aktif vaka sayisi, uye sayisi.
struct TeamsView: View {
    @State private var teams: [Team] = []
    @State private var isLoading = true
    @State private var showCreateSheet = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Ekip yapılarını yönetin ve aktif çözüm iş yüklerini izleyin.")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)

                    Button {
                        showCreateSheet = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus")
                            Text("Ekip Ekle").font(.system(size: 17, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(AppTheme.navy)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    content
                }
                .padding(16)
            }
        }
        .navigationTitle("Destek Ekipleri")
        .sheet(isPresented: $showCreateSheet) {
            CreateTeamSheet { Task { await load() } }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView().frame(maxWidth: .infinity).padding(.top, 40)
        } else if let errorMessage {
            VStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 36))
                    .foregroundStyle(.orange)
                Text(errorMessage)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Tekrar Dene") { Task { await load() } }
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        } else if teams.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "person.3")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("Henüz ekip oluşturulmamış.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        } else {
            ForEach(teams) { team in
                NavigationLink {
                    TeamDetailView(team: team, onChanged: { Task { await load() } })
                } label: {
                    TeamCard(team: team)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            teams = try await TeamService.shared.listTeams()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Ekipler yüklenemedi."
        }
    }
}

// MARK: - Ekip kartı

private struct TeamCard: View {
    let team: Team

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Text(team.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppTheme.navy)
                Spacer()
                HStack(spacing: 5) {
                    Image(systemName: team.activeTicketCount >= 20 ? "exclamationmark.triangle.fill" : "clock.fill")
                        .font(.system(size: 12))
                    Text("\(team.activeTicketCount) aktif vaka")
                        .font(.system(size: 13, weight: .semibold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(team.workloadColor.opacity(0.15))
                .foregroundStyle(team.workloadColor)
                .clipShape(Capsule())
            }

            if let description = team.description {
                Text(description)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }

            if !team.categoryNames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(team.categoryNames, id: \.self) { item in
                            Text(item)
                                .font(.system(size: 12, weight: .medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(AppTheme.inputBackground)
                                .foregroundStyle(AppTheme.navy)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            Divider()

            HStack {
                Image(systemName: "person.2.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                Text("\(team.memberCount) üye")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Yeni ekip oluşturma

private struct CreateTeamSheet: View {
    let onCreated: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Ekip Bilgileri") {
                    TextField("Ekip Adı", text: $name)
                    TextField("Açıklama (opsiyonel)", text: $description, axis: .vertical)
                        .lineLimit(2...4)
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
                        Text("Ekip Oluştur").frame(maxWidth: .infinity)
                    }
                }
                .disabled(name.count < 2 || isSubmitting)
            }
            .navigationTitle("Yeni Ekip")
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
            _ = try await TeamService.shared.createTeam(
                name: name, description: description.isEmpty ? nil : description
            )
            onCreated()
            dismiss()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Ekip oluşturulamadı."
        }
    }
}
