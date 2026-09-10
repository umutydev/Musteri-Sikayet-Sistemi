import SwiftUI

@main
struct SikayetApp: App {
    @StateObject private var auth = AuthManager.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.isLoading {
                    ProgressView()
                } else if let user = auth.currentUser {
                    RootTabView(role: user.role)
                } else {
                    LoginView()
                }
            }
            .environmentObject(auth)
        }
    }
}
