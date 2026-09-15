import SwiftUI

struct UserManagementView: View {
    @EnvironmentObject private var auth: AuthManager

    @State private var users: [UserDetail] = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var roleFilter: UserRole?
    @State private var showCreateSheet = false
    @State private var errorMessage: String?

    private var filtered: [UserDetail] {
        var result = users
        if let roleFilter {
            result = result.filter { $0.role == roleFilter }
        }
        if !searchText.isEmpty {
            result = result.filter {
                $0.fullName.localizedCaseInsensitiveContains(searchText) ||
                $0.email.localizedCaseInsensitiveContains(searchText)
            }
        }
        return result
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Arama
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("İsim veya e-posta ile ara...", text: $searchText)
                        .textInputAutocapitalization(.never)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(AppTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
                .padding(.top, 8)

                // Rol filtresi
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        FilterChip(title: "Tümü", isSelected: roleFilter == nil) {
                            roleFilter = nil
                        }
                        ForEach([UserRole.customer, .agent, .admin], id: \.self) { role in
                            FilterChip(title: role.displayName, isSelected: roleFilter == role) {
                                roleFilter = role
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.vertical, 14)

                content
            }
        }
        .navigationTitle("Kullanıcı Yönetimi")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateSheet = true
                } label: {
                    Image(systemName: "person.badge.plus")
                }
            }
        }
        .sheet(isPresented: $showCreateSheet) {
            CreateUserSheet { Task { await load() } }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            Spacer()
            ProgressView()
            Spacer()
        } else if let errorMessage {
            Spacer()
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
            .padding(32)
            Spacer()
        } else if filtered.isEmpty {
            Spacer()
            Text("Kullanıcı bulunamadı.")
                .foregroundStyle(.secondary)
            Spacer()
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filtered) { user in
                        UserRow(
                            user: user,
                            isSelf: user.id == auth.currentUser?.id,
                            onToggleActive: { Task { await toggleActive(user) } }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            users = try await UserService.shared.listUsers()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Kullanıcılar yüklenemedi."
        }
    }

    private func toggleActive(_ user: UserDetail) async {
        do {
            let updated = try await UserService.shared.toggleActive(user: user)
            if let index = users.firstIndex(where: { $0.id == updated.id }) {
                users[index] = updated
            }
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "İşlem başarısız."
        }
    }
}

// MARK: - Kullanıcı satırı

private struct UserRow: View {
    let user: UserDetail
    let isSelf: Bool
    let onToggleActive: () -> Void

    private var roleColor: Color {
        switch user.role {
        case .admin: return AppTheme.primary
        case .agent: return Color(red: 0.05, green: 0.5, blue: 0.45)
        case .customer: return .gray
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Circle()
                    .fill(roleColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Text(initials)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(roleColor)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(user.fullName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.navy)
                    Text(user.email)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }

            HStack(spacing: 8) {
                Text(user.role.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(roleColor.opacity(0.15))
                    .foregroundStyle(roleColor)
                    .clipShape(Capsule())

                HStack(spacing: 5) {
                    Circle()
                        .fill(user.isActive ? .green : .red)
                        .frame(width: 7, height: 7)
                    Text(user.isActive ? "Aktif" : "Pasif")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(user.isActive ? .green : .red)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background((user.isActive ? Color.green : Color.red).opacity(0.12))
                .clipShape(Capsule())

                Spacer()

                // Admin kendi hesabini pasiflestiremez - backend de bunu 400 ile reddeder,
                // butonu gizleyerek kullaniciyi bosuna denemeye zorlamıyoruz
                if !isSelf {
                    Button(action: onToggleActive) {
                        Text(user.isActive ? "Pasifleştir" : "Aktifleştir")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(user.isActive ? .red : .green)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var initials: String {
        user.fullName.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
    }
}

// MARK: - Yeni kullanıcı oluşturma

private struct CreateUserSheet: View {
    let onCreated: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var fullName = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var password = ""
    @State private var role: UserRole = .agent
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var isValid: Bool {
        fullName.count >= 2 && email.contains("@") && password.count >= 8
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Kullanıcı Bilgileri") {
                    TextField("Ad Soyad", text: $fullName)
                    TextField("E-posta", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    TextField("Telefon (opsiyonel)", text: $phone)
                        .keyboardType(.phonePad)
                    SecureField("Geçici Şifre (en az 8 karakter)", text: $password)
                }

                Section("Rol") {
                    Picker("Rol", selection: $role) {
                        Text("Temsilci").tag(UserRole.agent)
                        Text("Yönetici").tag(UserRole.admin)
                    }
                    .pickerStyle(.segmented)
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
                        Text("Kullanıcı Oluştur").frame(maxWidth: .infinity)
                    }
                }
                .disabled(!isValid || isSubmitting)
            }
            .navigationTitle("Yeni Kullanıcı")
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
            let request = UserCreateRequest(
                fullName: fullName, email: email,
                phone: phone.isEmpty ? nil : phone,
                password: password, role: role
            )
            _ = try await UserService.shared.createUser(request)
            onCreated()
            dismiss()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Kullanıcı oluşturulamadı."
        }
    }
}
