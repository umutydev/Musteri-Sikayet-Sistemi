import SwiftUI


struct RootTabView: View {
    let role: UserRole

    var body: some View {
        switch role {
        case .customer: CustomerTabView()
        case .agent: AgentTabView()
        case .admin: AdminTabView()
        }
    }
}

struct CustomerTabView: View {
    var body: some View {
        TabView {
            CustomerHomeView().tabItem { Label("Ana Sayfa", systemImage: "house.fill") }
            MyTicketsView().tabItem { Label("Şikayetlerim", systemImage: "list.bullet.rectangle") }
            NotificationsView().tabItem { Label("Bildirimler", systemImage: "bell.fill") }
            ProfileView().tabItem { Label("Profil", systemImage: "person.fill") }
        }
        .tint(AppTheme.primary)
    }
}

struct AgentTabView: View {
    var body: some View {
        TabView {
            AgentTasksView().tabItem { Label("Görevler", systemImage: "list.clipboard.fill") }
            NotificationsView().tabItem { Label("Bildirimler", systemImage: "bell.fill") }
            ProfileView().tabItem { Label("Profil", systemImage: "person.fill") }
        }
        .tint(AppTheme.primary)
    }
}

struct AdminTabView: View {
    var body: some View {
        TabView {
            AdminOverviewView().tabItem { Label("Genel Bakış", systemImage: "chart.bar.fill") }
            AgentTasksView().tabItem { Label("Görevler", systemImage: "list.clipboard.fill") }
            AdminSettingsHubView().tabItem { Label("Ayarlar", systemImage: "gearshape.fill") }
            ProfileView().tabItem { Label("Profil", systemImage: "person.fill") }
        }
        .tint(AppTheme.primary)
    }
}
