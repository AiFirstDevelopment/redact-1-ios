import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var onboardingService = OnboardingService.shared

    @State private var identifier = ""
    @State private var password = ""
    @State private var showPassword = false
    @State private var selectedIdentifierType: LoginIdentifierType?

    private var agency: AgencyConfig? {
        onboardingService.currentAgency
    }

    private var loginIdentifiers: [LoginIdentifierType] {
        agency?.loginIdentifiers ?? [.email]
    }

    private var currentType: LoginIdentifierType {
        selectedIdentifierType ?? agency?.primaryIdentifier ?? .email
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
            .onAppear {
                selectedIdentifierType = agency?.primaryIdentifier
            }
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
            // Identifier type picker (if multiple types supported)
            if loginIdentifiers.count > 1 {
                identifierTypePicker
            }

            // Identifier field
            identifierField

            // Password field
            passwordField

            // Login button
            loginButton
        }
    }

    private var identifierTypePicker: some View {
        HStack(spacing: 8) {
            ForEach(loginIdentifiers, id: \.self) { type in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedIdentifierType = type
                        identifier = "" // Clear when switching types
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: type.icon)
                            .font(.caption)
                        Text(type.displayName)
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(currentType == type ? .white : .white.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        currentType == type
                            ? Color.white.opacity(0.25)
                            : Color.white.opacity(0.1)
                    )
                    .clipShape(Capsule())
                }
            }
        }
    }

    private var identifierField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(currentType.displayName)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))

            HStack {
                Image(systemName: currentType.icon)
                    .foregroundStyle(.white.opacity(0.7))

                TextField("", text: $identifier, prompt: Text(currentType.placeholder).foregroundStyle(.white.opacity(0.4)))
                    .keyboardType(keyboardType(for: currentType))
                    .textContentType(contentType(for: currentType))
                    .autocapitalization(currentType == .email ? .none : .allCharacters)
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
            Text("Use: admin@example.com / password123")
                .font(.caption2)
        }
        .foregroundStyle(.white.opacity(0.6))
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private var canSubmit: Bool {
        !identifier.isEmpty && !password.isEmpty
    }

    private func performLogin() {
        Task {
            // For now, always use email login since backend uses email
            // In production, you'd send the identifier type to the backend
            let loginEmail: String
            if currentType == .email {
                loginEmail = identifier
            } else {
                // For badge/employee ID, we'd need backend support
                // For now, just use the identifier as email for demo
                loginEmail = identifier
            }
            await authService.login(email: loginEmail, password: password)
        }
    }

    private func keyboardType(for type: LoginIdentifierType) -> UIKeyboardType {
        switch type {
        case .email: return .emailAddress
        case .badgeNumber: return .numberPad
        case .employeeId: return .default
        }
    }

    private func contentType(for type: LoginIdentifierType) -> UITextContentType? {
        switch type {
        case .email: return .emailAddress
        default: return nil
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthService.shared)
}
