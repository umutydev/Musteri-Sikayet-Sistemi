import SwiftUI

struct AdminSettingsHubView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Kullanıcı Yönetimi") { UserManagementView() }
                NavigationLink("Destek Ekipleri") { TeamsView() }
                NavigationLink("Sistem Kategorileri") { CategoryManagementView() }
            }
            .navigationTitle("Ayarlar")
        }
    }
}
