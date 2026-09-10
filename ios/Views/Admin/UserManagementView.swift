import SwiftUI

/// NOT: Backend'de /users endpoint'i henüz yok. UI hazır, load() güncellenecek.
struct UserManagementView: View {
    var body: some View {
        List {
            Text("Kullanıcı listesi burada görünecek.")
                .foregroundStyle(.secondary)
        }
        .searchable(text: .constant(""), prompt: "İsim, e-posta veya ID ile ara...")
        .navigationTitle("Kullanıcı Yönetimi")
        .toolbar { ToolbarItem(placement: .primaryAction) { Button("Yeni Kullanıcı Ekle") {} } }
    }
}
