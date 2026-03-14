import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService

    private var isAdmin: Bool {
        authService.currentUser?.role == .admin
    }

    var body: some View {
        TabView {
            NavigationStack {
                RequestListView()
            }
            .tabItem {
                Label("Requests", systemImage: "doc.text")
            }

            if isAdmin {
                NavigationStack {
                    UsersView()
                }
                .tabItem {
                    Label("Users", systemImage: "person.2")
                }
            }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthService.shared)
}
