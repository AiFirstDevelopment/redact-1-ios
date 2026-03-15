import SwiftUI

// MARK: - Onboarding View

struct OnboardingView: View {
    @StateObject private var onboardingService = OnboardingService.shared
    @State private var orgCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var onOnboardingComplete: (AgencyConfig) -> Void

    var body: some View {
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

                    // Logo and welcome
                    headerSection

                    // Code input
                    codeInput

                    // Error message
                    errorSection

                    // Connect button
                    connectButton

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 32)
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // App icon
            Image(systemName: "doc.viewfinder")
                .font(.system(size: 70))
                .foregroundStyle(.white)
                .padding(24)
                .background(Circle().fill(.white.opacity(0.2)))

            Text("Redact-1")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Connect to Your Agency")
                .font(.title3.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))
        }
    }

    // MARK: - Code Input

    private var codeInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Department Code")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))

            HStack {
                Image(systemName: "building.2")
                    .foregroundStyle(.white.opacity(0.7))

                TextField("", text: $orgCode, prompt: Text("Enter code").foregroundStyle(.white.opacity(0.4)))
                    .textContentType(.organizationName)
                    .autocapitalization(.allCharacters)
                    .autocorrectionDisabled()
                    .foregroundStyle(.white)

                if !orgCode.isEmpty {
                    Button(action: { orgCode = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .padding()
            .background(.white.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("This code was provided by your records administrator")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    // MARK: - Error Section

    @ViewBuilder
    private var errorSection: some View {
        if let error = errorMessage {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(error)
                    .font(.subheadline)
            }
            .foregroundStyle(.white)
            .padding()
            .background(Color.red.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .onTapGesture {
                errorMessage = nil
            }
        }
    }

    // MARK: - Connect Button

    private var connectButton: some View {
        Button(action: performEnrollment) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "link.badge.plus")
                    Text("Connect")
                        .fontWeight(.semibold)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(canConnect ? Color.white.opacity(0.25) : Color.white.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(!canConnect || isLoading)
    }

    // MARK: - Helpers

    private var canConnect: Bool {
        !orgCode.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func performEnrollment() {
        Task {
            isLoading = true
            errorMessage = nil

            do {
                let config = try await onboardingService.enrollWithCode(orgCode)
                onOnboardingComplete(config)
            } catch let error as OnboardingError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = "An unexpected error occurred"
            }

            isLoading = false
        }
    }
}

// MARK: - QR Scanner View (kept for potential future use)

struct QRScannerView: View {
    var onScan: (String) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                Text("QR Scanner")
            }
            .navigationTitle("Scan QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview

#Preview("Onboarding") {
    OnboardingView { config in
        print("Enrolled with: \(config.name)")
    }
}
