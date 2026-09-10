import SwiftUI

struct RootView: View {
    @StateObject private var auth = AuthManager.shared

    var body: some View {
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
