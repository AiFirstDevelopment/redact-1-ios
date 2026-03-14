import SwiftUI

// MARK: - Onboarding View

struct OnboardingView: View {
    @StateObject private var onboardingService = OnboardingService.shared
    @State private var selectedMethod: EnrollmentMethod = .code
    @State private var orgCode = ""
    @State private var email = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showScanner = false

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
                    Spacer(minLength: 40)

                    // Logo and welcome
                    headerSection

                    // Enrollment method picker
                    methodPicker

                    // Method-specific input
                    inputSection

                    // Error message
                    errorSection

                    // Connect button
                    connectButton

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 32)
            }
        }
        .sheet(isPresented: $showScanner) {
            QRScannerView { code in
                showScanner = false
                Task {
                    await enrollWithQRCode(code)
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // App icon
            Image("AppIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)

            Text("Redact-1")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Connect to Your Agency")
                .font(.title3.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))

            Text("Enter your agency code or scan the QR code provided by your records administrator")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    // MARK: - Method Picker

    private var methodPicker: some View {
        HStack(spacing: 8) {
            ForEach(EnrollmentMethod.allCases, id: \.self) { method in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedMethod = method
                        errorMessage = nil
                    }
                }) {
                    VStack(spacing: 6) {
                        Image(systemName: method.icon)
                            .font(.title3)
                        Text(method.title)
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(selectedMethod == method ? .white : .white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        selectedMethod == method
                            ? Color.white.opacity(0.25)
                            : Color.white.opacity(0.1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    // MARK: - Input Section

    @ViewBuilder
    private var inputSection: some View {
        switch selectedMethod {
        case .code:
            codeInput
        case .email:
            emailInput
        case .qrCode:
            qrCodeSection
        }
    }

    private var codeInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Agency Code")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))

            HStack {
                Image(systemName: "building.2")
                    .foregroundStyle(.white.opacity(0.7))

                TextField("", text: $orgCode, prompt: Text("e.g. SPRINGFIELD-PD").foregroundStyle(.white.opacity(0.4)))
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

            Text("This code was provided by your agency's records administrator")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var emailInput: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Work Email")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))

            HStack {
                Image(systemName: "envelope")
                    .foregroundStyle(.white.opacity(0.7))

                TextField("", text: $email, prompt: Text("user@agency.gov").foregroundStyle(.white.opacity(0.4)))
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .foregroundStyle(.white)

                if !email.isEmpty {
                    Button(action: { email = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .padding()
            .background(.white.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("We'll detect your agency from your email domain")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var qrCodeSection: some View {
        VStack(spacing: 16) {
            Button(action: { showScanner = true }) {
                VStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(style: StrokeStyle(lineWidth: 3, dash: [10]))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 200, height: 200)

                        VStack(spacing: 12) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 60))
                                .foregroundStyle(.white)

                            Text("Tap to Scan")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                    }
                }
            }

            Text("Scan the QR code displayed in your agency's onboarding materials")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 20)
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
                    Text("Connect to Agency")
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
        switch selectedMethod {
        case .code:
            return !orgCode.trimmingCharacters(in: .whitespaces).isEmpty
        case .email:
            return email.contains("@") && email.contains(".")
        case .qrCode:
            return false // QR triggers directly
        }
    }

    private func performEnrollment() {
        Task {
            isLoading = true
            errorMessage = nil

            do {
                let config: AgencyConfig
                switch selectedMethod {
                case .code:
                    config = try await onboardingService.enrollWithCode(orgCode)
                case .email:
                    config = try await onboardingService.enrollWithEmail(email)
                case .qrCode:
                    return // Handled by scanner
                }
                onOnboardingComplete(config)
            } catch let error as OnboardingError {
                errorMessage = error.errorDescription
            } catch {
                errorMessage = "An unexpected error occurred"
            }

            isLoading = false
        }
    }

    private func enrollWithQRCode(_ content: String) async {
        isLoading = true
        errorMessage = nil

        do {
            let config = try await onboardingService.enrollWithQRCode(content)
            onOnboardingComplete(config)
        } catch let error as OnboardingError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = "Invalid QR code"
        }

        isLoading = false
    }
}

// MARK: - QR Scanner View (Placeholder)

struct QRScannerView: View {
    var onScan: (String) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Camera preview placeholder
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.black)
                        .frame(width: 280, height: 280)

                    // Scanning frame overlay
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 200, height: 200)

                    VStack(spacing: 16) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.white.opacity(0.5))

                        Text("Camera Preview")
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

                Text("Position the QR code within the frame")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                // Demo buttons for testing
                #if DEBUG
                VStack(spacing: 12) {
                    Text("Demo Codes")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        demoButton("Springfield", code: "ORG:SPRINGFIELD")
                        demoButton("Riverside", code: "ORG:RIVERSIDE")
                        demoButton("Metro", code: "ORG:METRO")
                    }
                }
                .padding(.top, 20)
                #endif

                Spacer()
            }
            .padding()
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

    private func demoButton(_ title: String, code: String) -> some View {
        Button(action: { onScan(code) }) {
            Text(title)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .clipShape(Capsule())
        }
    }
}

// MARK: - Preview

#Preview("Onboarding") {
    OnboardingView { config in
        print("Enrolled with: \(config.name)")
    }
}

#Preview("QR Scanner") {
    QRScannerView { code in
        print("Scanned: \(code)")
    }
}
