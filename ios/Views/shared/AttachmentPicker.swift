import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Fotograf kutuphanesinden veya Dosyalar uygulamasindan dosya secmeyi saglar.
/// Secilen dosyalar bellekte PendingAttachment olarak tutulur, henuz sunucuya gitmez.
struct AttachmentPicker: View {
    @Binding var attachments: [PendingAttachment]
    var maxCount: Int = 5

    @State private var photoItem: PhotosPickerItem?
    @State private var showFileImporter = false
    @State private var errorMessage: String?

    private let maxBytes = 10 * 1024 * 1024  // 10MB - backend limitiyle ayni

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Dosya/Fotoğraf Ekle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.navy)

            // Secilmis dosyalar
            if !attachments.isEmpty {
                VStack(spacing: 8) {
                    ForEach(attachments) { item in
                        HStack(spacing: 12) {
                            Image(systemName: item.contentType == "application/pdf" ? "doc.text.fill" : "photo.fill")
                                .foregroundStyle(AppTheme.primary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.fileName)
                                    .font(.system(size: 14, weight: .medium))
                                    .lineLimit(1)
                                Text(item.sizeText)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                attachments.removeAll { $0.id == item.id }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(12)
                        .background(AppTheme.inputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }

            // Ekleme alani
            if attachments.count < maxCount {
                HStack(spacing: 12) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        pickerButton(icon: "photo", title: "Fotoğraf")
                    }

                    Button {
                        showFileImporter = true
                    } label: {
                        pickerButton(icon: "doc", title: "Dosya")
                    }
                }
            }

            Text("\(attachments.count)/\(maxCount) dosya · PNG, JPG, PDF (Maks. 10MB)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .onChange(of: photoItem) { _, newItem in
            Task { await handlePhotoSelection(newItem) }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.pdf, .png, .jpeg],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result)
        }
    }

    private func pickerButton(icon: String, title: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(title).font(.system(size: 15, weight: .medium))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(AppTheme.inputBackground)
        .foregroundStyle(AppTheme.primary)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Seçim işlemleri

    private func handlePhotoSelection(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        errorMessage = nil

        guard let data = try? await item.loadTransferable(type: Data.self) else {
            errorMessage = "Fotoğraf okunamadı."
            return
        }
        guard data.count <= maxBytes else {
            errorMessage = "Dosya boyutu 10MB'ı aşamaz."
            return
        }

        // PhotosPicker dosya adi vermez, kendimiz uretiyoruz
        let name = "foto_\(Int(Date().timeIntervalSince1970)).jpg"
        attachments.append(PendingAttachment(fileName: name, contentType: "image/jpeg", data: data))
        photoItem = nil
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        errorMessage = nil
        guard case .success(let urls) = result, let url = urls.first else { return }

        // Dosyalar uygulamasindan gelen URL'ler guvenlik kapsamli - once erisim izni alinmali
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Dosyaya erişilemedi."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let data = try? Data(contentsOf: url) else {
            errorMessage = "Dosya okunamadı."
            return
        }
        guard data.count <= maxBytes else {
            errorMessage = "Dosya boyutu 10MB'ı aşamaz."
            return
        }

        let contentType: String
        switch url.pathExtension.lowercased() {
        case "pdf": contentType = "application/pdf"
        case "png": contentType = "image/png"
        default: contentType = "image/jpeg"
        }

        attachments.append(
            PendingAttachment(fileName: url.lastPathComponent, contentType: contentType, data: data)
        )
    }
}
