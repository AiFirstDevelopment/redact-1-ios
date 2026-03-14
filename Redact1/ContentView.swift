import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var onboardingService = OnboardingService.shared
    @State private var isOnboarded: Bool?

    var body: some View {
        Group {
            if let onboarded = isOnboarded {
                if onboarded {
                    authStateView
                } else {
                    OnboardingView { _ in
                        withAnimation {
                            isOnboarded = true
                        }
                    }
                }
            } else {
                loadingView
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isOnboarded)
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
        .task {
            isOnboarded = onboardingService.isOnboarded
        }
    }

    @ViewBuilder
    private var authStateView: some View {
        if authService.isAuthenticated {
            MainTabView()
        } else {
            LoginView()
        }
    }

    private var loadingView: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.6), Color.indigo.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Image("AppIcon")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.2)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthService.shared)
}
