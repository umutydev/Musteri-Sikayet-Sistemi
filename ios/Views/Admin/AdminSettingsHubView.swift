import SwiftUI

struct AdminSettingsHubView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()
                List {
                    NavigationLink {
                        UserManagementView()
                    } label: {
                        Label("Kullanıcı Yönetimi", systemImage: "person.3.fill")
                    }

                    NavigationLink {
                        TeamsView()
                    } label: {
                        Label("Destek Ekipleri", systemImage: "person.2.badge.gearshape.fill")
                    }

                    NavigationLink {
                        CategoryManagementView()
                    } label: {
                        Label("Sistem Kategorileri", systemImage: "folder.fill")
                    }
                }
            }
            .navigationTitle("Ayarlar")
        }
    }
}
