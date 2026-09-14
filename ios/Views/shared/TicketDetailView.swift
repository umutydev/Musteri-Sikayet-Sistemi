import SwiftUI

struct TicketDetailView: View {
    let ticketId: UUID
    @EnvironmentObject private var auth: AuthManager

    @State private var ticket: Ticket?
    @State private var notes: [TicketNote] = []
    @State private var newNoteText = ""
    @State private var isInternalNote = false
    @State private var showResolveSheet = false
    @State private var attachments: [Attachment] = []
    @State private var previewItem: PreviewItem?
    @State private var downloadingId: UUID?


    private var isStaff: Bool {
        auth.currentUser?.role == .agent || auth.currentUser?.role == .admin
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                if let ticket {
                    VStack(spacing: 16) {
                        headerCard(ticket)
                        descriptionCard(ticket)
                        if !attachments.isEmpty { attachmentsCard }
                        timelineCard(ticket)
                        if isStaff { staffActionsCard(ticket) }
                        messagesCard
                    }
                    .padding(16)
                } else {
                    ProgressView().padding(.top, 80)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .refreshable { await load() }
        .sheet(item: $previewItem) { item in
            FilePreview(url: item.url)
        }
    }

    private func headerCard(_ t: Ticket) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("ŞİKAYET #\(t.referenceNo)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                StatusBadge(status: t.status)
            }
            Text(t.subject)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(AppTheme.navy)
                .multilineTextAlignment(.leading)
            HStack(spacing: 16) {
                Label(t.type.displayName, systemImage: "tag")
                Label("Gönderildi: \(t.createdAt.formatted(date: .abbreviated, time: .omitted))", systemImage: "calendar")
            }
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    private var attachmentsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ekli Dosyalar (\(attachments.count))")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(AppTheme.navy)

            ForEach(attachments) { item in
                Button {
                    Task { await openAttachment(item) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: item.iconName)
                            .font(.system(size: 20))
                            .foregroundStyle(AppTheme.primary)
                            .frame(width: 40, height: 40)
                            .background(AppTheme.primary.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.fileName)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(AppTheme.navy)
                                .lineLimit(1)
                            Text(item.uploadedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if downloadingId == item.id {
                            ProgressView()
                        } else {
                            Image(systemName: "eye")
                                .foregroundStyle(AppTheme.primary)
                        }
                    }
                    .padding(12)
                    .background(AppTheme.inputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func descriptionCard(_ t: Ticket) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Açıklama")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(AppTheme.navy)
            Text(t.description)
                .font(.system(size: 16))
                .foregroundStyle(.primary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func openAttachment(_ item: Attachment) async {
        downloadingId = item.id
        defer { downloadingId = nil }
        do {
            let url = try await AttachmentService.shared.download(ticketId: ticketId, attachment: item)
            previewItem = PreviewItem(url: url)
        } catch {
            print("❌ İndirme hatası: \(error)")
        }
    }
    /// Tasarımdaki "Süreç Akışı" — durumun hangi aşamada olduğunu gösteren dikey çizelge
    private func timelineCard(_ t: Ticket) -> some View {
        let steps: [(TicketStatus, String)] = [
            (.new, "Gönderildi"),
            (.inReview, "İncelemede"),
            (t.status == .rejected ? .rejected : .resolved, t.status == .rejected ? "Reddedildi" : "Çözüldü")
        ]
        let currentIndex: Int = {
            switch t.status {
            case .new: return 0
            case .inReview, .pendingInfo: return 1
            case .resolved, .rejected, .closed: return 2
            }
        }()

        return VStack(alignment: .leading, spacing: 14) {
            Text("Süreç Akışı")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(AppTheme.navy)

            ForEach(Array(steps.enumerated().reversed()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        Circle()
                            .fill(index <= currentIndex ? step.0.color : Color.gray.opacity(0.25))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: index <= currentIndex ? "checkmark" : "circle")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                        if index > 0 {
                            Rectangle()
                                .fill(Color.gray.opacity(0.25))
                                .frame(width: 2, height: 28)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.1)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(index <= currentIndex ? AppTheme.navy : .secondary)
                        Text(index <= currentIndex ? "Tamamlandı" : "Bekliyor")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func staffActionsCard(_ t: Ticket) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("İşlemler")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(AppTheme.navy)

            if t.status == .new || t.status == .inReview {
                Button {
                    showResolveSheet = true
                } label: {
                    Text("Sonuçlandır")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(AppTheme.navy)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            Toggle("Dahili Not (müşteri göremez)", isOn: $isInternalNote)
                .font(.system(size: 15))
                .tint(AppTheme.primary)

            TextField(
                isInternalNote ? "Özel bir not ekleyin..." : "Müşteriye yanıt yazın...",
                text: $newNoteText, axis: .vertical
            )
            .lineLimit(3...6)
            .padding(14)
            .background(AppTheme.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                Task { await submitNote() }
            } label: {
                Text("Not Ekle")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(newNoteText.isEmpty ? Color.gray.opacity(0.3) : AppTheme.primary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(newNoteText.isEmpty)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $showResolveSheet) {
            ResolveTicketSheet(ticketId: ticketId) { self.ticket = $0 }
        }
    }

    private var messagesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(isStaff ? "Notlar" : "Mesajlar")
                .font(.system(size: 19, weight: .bold))
                .foregroundStyle(AppTheme.navy)

            if notes.isEmpty {
                Text("Henüz mesaj yok.")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(notes) { note in
                    VStack(alignment: .leading, spacing: 6) {
                        if note.isInternal {
                            Label("Dahili Not", systemImage: "lock.fill")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.orange)
                        }
                        Text(note.content)
                            .font(.system(size: 15))
                        Text(note.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(note.isInternal ? Color.orange.opacity(0.1) : AppTheme.inputBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func load() async {
        async let t = TicketService.shared.getTicket(id: ticketId)
        async let n = TicketService.shared.listNotes(ticketId: ticketId)
        async let a = AttachmentService.shared.listAttachments(ticketId: ticketId)
        ticket = try? await t
        notes = (try? await n) ?? []
        attachments = (try? await a) ?? []
    }

    private func submitNote() async {
        _ = try? await TicketService.shared.addNote(ticketId: ticketId, content: newNoteText, isInternal: isInternalNote)
        newNoteText = ""
        await load()
    }
}

private struct ResolveTicketSheet: View {
    let ticketId: UUID
    let onResolved: (Ticket) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var status: TicketStatus = .resolved
    @State private var note = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 18) {
                    Picker("Sonuç", selection: $status) {
                        Text("Çözüldü").tag(TicketStatus.resolved)
                        Text("Reddedildi").tag(TicketStatus.rejected)
                    }
                    .pickerStyle(.segmented)

                    Text("Sonuç Açıklaması")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.navy)

                    TextEditor(text: $note)
                        .frame(minHeight: 120)
                        .padding(10)
                        .scrollContentBackground(.hidden)
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Text("En az 20 karakter (\(note.count)/20)")
                        .font(.caption)
                        .foregroundStyle(note.count >= 20 ? .green : .secondary)

                    if let errorMessage {
                        Text(errorMessage).font(.footnote).foregroundStyle(.red)
                    }

                    Button {
                        Task { await submit() }
                    } label: {
                        Text("Kaydı Sonuçlandır")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(note.count < 20 ? Color.gray.opacity(0.3) : AppTheme.navy)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(note.count < 20)

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Sonuçlandır")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { dismiss() }
                }
            }
        }
    }

    private func submit() async {
        do {
            let updated = try await TicketService.shared.updateStatus(id: ticketId, newStatus: status, resolutionNote: note)
            onResolved(updated)
            dismiss()
        } catch {
            errorMessage = (error as? APIError)?.errorDescription ?? "Bir hata oluştu."
        }
    }
}
