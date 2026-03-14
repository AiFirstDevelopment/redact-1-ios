import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack {
                RequestListView()
            }
            .tabItem {
                Label("Requests", systemImage: "doc.text")
            }

            NavigationStack {
                UsersView()
            }
            .tabItem {
                Label("Users", systemImage: "person.2")
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
