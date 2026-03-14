import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var onboardingService = OnboardingService.shared

    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false

    private var agency: AgencyConfig? {
        onboardingService.currentAgency
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.blue.opacity(0.7), Color.indigo.opacity(0.9)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        Spacer(minLength: 60)

                        // Logo section
                        logoSection

                        // Credentials section
                        credentialsSection

                        // Error section
                        errorSection

                        // Development hint
                        #if DEBUG
                        developmentHint
                        #endif

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 32)
                }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Logo Section

    private var logoSection: some View {
        VStack(spacing: 16) {
            Image("AppIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 90, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)

            Text("Redact-1")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            if let agency = agency {
                Text(agency.name)
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.9))
            }
        }
    }

    // MARK: - Credentials Section

    private var credentialsSection: some View {
        VStack(spacing: 20) {
            // Email field
            emailField

            // Password field
            passwordField

            // Login button
            loginButton
        }
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Email")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))

            HStack {
                Image(systemName: "envelope")
                    .foregroundStyle(.white.opacity(0.7))

                TextField("", text: $email, prompt: Text("you@agency.gov").foregroundStyle(.white.opacity(0.4)))
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .foregroundStyle(.white)
            }
            .padding()
            .background(.white.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Password")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))

            HStack {
                Image(systemName: "lock")
                    .foregroundStyle(.white.opacity(0.7))

                if showPassword {
                    TextField("", text: $password)
                        .foregroundStyle(.white)
                } else {
                    SecureField("", text: $password)
                        .foregroundStyle(.white)
                }

                Button(action: { showPassword.toggle() }) {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding()
            .background(.white.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var loginButton: some View {
        Button(action: performLogin) {
            HStack {
                if authService.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Sign In")
                        .fontWeight(.semibold)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(canSubmit ? Color.white.opacity(0.25) : Color.white.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(!canSubmit || authService.isLoading)
    }

    // MARK: - Error Section

    @ViewBuilder
    private var errorSection: some View {
        if let error = authService.error {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(error)
                    .font(.subheadline)
            }
            .foregroundStyle(.white)
            .padding()
            .background(Color.red.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Development Hint

    private var developmentHint: some View {
        VStack(spacing: 4) {
            Text("Development Mode")
                .font(.caption.weight(.medium))
            Text("Use: clerk@pd.local / test-password")
                .font(.caption2)
        }
        .foregroundStyle(.white.opacity(0.6))
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty
    }

    private func performLogin() {
        Task {
            await authService.login(email: email, password: password)
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthService.shared)
}
