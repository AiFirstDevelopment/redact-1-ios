import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var onboardingService = OnboardingService.shared
    @State private var email = ""
    @State private var password = ""

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
                    VStack(spacing: 24) {
                        Spacer(minLength: 60)

                        // Logo/Title
                        VStack(spacing: 12) {
                            Image("AppIcon")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 22))
                                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)

                            Text("Redact-1")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)

                            if let agency = onboardingService.currentAgency {
                                Text(agency.name)
                                    .font(.headline)
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        }

                        Spacer(minLength: 40)

                        // Login form
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Email")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.9))

                                HStack {
                                    Image(systemName: "envelope")
                                        .foregroundStyle(.white.opacity(0.7))

                                    TextField("", text: $email, prompt: Text("you@agency.gov").foregroundStyle(.white.opacity(0.4)))
                                        .textContentType(.emailAddress)
                                        .autocapitalization(.none)
                                        .keyboardType(.emailAddress)
                                        .foregroundStyle(.white)
                                }
                                .padding()
                                .background(.white.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.white.opacity(0.9))

                                HStack {
                                    Image(systemName: "lock")
                                        .foregroundStyle(.white.opacity(0.7))

                                    SecureField("", text: $password, prompt: Text("Enter password").foregroundStyle(.white.opacity(0.4)))
                                        .textContentType(.password)
                                        .foregroundStyle(.white)
                                }
                                .padding()
                                .background(.white.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

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

                            Button(action: login) {
                                HStack {
                                    if authService.isLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: "arrow.right.circle.fill")
                                        Text("Sign In")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(canLogin ? Color.white.opacity(0.25) : Color.white.opacity(0.1))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .disabled(!canLogin || authService.isLoading)
                        }
                        .padding(.horizontal, 32)

                        Spacer(minLength: 60)
                    }
                }
            }
            .navigationBarHidden(true)
        }
    }

    private var canLogin: Bool {
        !email.isEmpty && !password.isEmpty
    }

    private func login() {
        Task {
            await authService.login(email: email, password: password)
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthService.shared)
}
