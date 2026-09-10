import SwiftUI

/// NOT: Backend'de teams tablosu henüz yok — eklenmesi gerekiyor (bkz. DB tasarım dokümanı notu).
struct TeamsView: View {
    var body: some View {
        List {
            Text("Ekip listesi burada görünecek.")
                .foregroundStyle(.secondary)
        }
        .navigationTitle("Destek Ekipleri")
        .toolbar { ToolbarItem(placement: .primaryAction) { Button("Ekip Ekle") {} } }
    }
}
