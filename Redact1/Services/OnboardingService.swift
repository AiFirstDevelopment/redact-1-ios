import Foundation

// MARK: - Login Identifier Types

enum LoginIdentifierType: String, Codable, CaseIterable {
    case email
    case badgeNumber
    case employeeId

    var displayName: String {
        switch self {
        case .email: return "Email"
        case .badgeNumber: return "Badge"
        case .employeeId: return "Employee ID"
        }
    }

    var placeholder: String {
        switch self {
        case .email: return "you@agency.gov"
        case .badgeNumber: return "12345"
        case .employeeId: return "EMP-001"
        }
    }

    var icon: String {
        switch self {
        case .email: return "envelope"
        case .badgeNumber: return "shield"
        case .employeeId: return "person.text.rectangle"
        }
    }
}

// MARK: - Agency Configuration

struct AgencyConfig: Codable, Equatable {
    let code: String
    let name: String
    let apiBaseUrl: String
    let loginIdentifiers: [LoginIdentifierType]
    let primaryColor: String?
    let supportEmail: String?
    let supportPhone: String?

    var primaryIdentifier: LoginIdentifierType {
        loginIdentifiers.first ?? .email
    }

    static var `default`: AgencyConfig {
        AgencyConfig(
            code: "DEFAULT",
            name: "Default Agency",
            apiBaseUrl: "https://redact-1-worker.joelstevick.workers.dev",
            loginIdentifiers: [.email, .badgeNumber],
            primaryColor: "#1E40AF",
            supportEmail: nil,
            supportPhone: nil
        )
    }
}

// MARK: - Onboarding Service

@MainActor
final class OnboardingService: ObservableObject {
    static let shared = OnboardingService()

    @Published var isOnboarded: Bool = false
    @Published var currentAgency: AgencyConfig?

    private let agencyKey = "redact1_agency_config"

    private init() {
        loadStoredAgency()
    }

    private func loadStoredAgency() {
        if let data = UserDefaults.standard.data(forKey: agencyKey),
           let agency = try? JSONDecoder().decode(AgencyConfig.self, from: data) {
            currentAgency = agency
            isOnboarded = true
        }
    }

    // MARK: - Enrollment Methods

    func enrollWithCode(_ code: String) async throws -> AgencyConfig {
        let normalizedCode = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // In production: fetch from server
        // For now: use mock configs
        let config = try mockConfigForCode(normalizedCode)
        saveAgency(config)
        return config
    }

    func enrollWithEmail(_ email: String) async throws -> AgencyConfig {
        guard let domain = email.split(separator: "@").last else {
            throw OnboardingError.invalidEmail
        }

        let normalizedDomain = String(domain).lowercased()
        let config = try mockConfigForDomain(normalizedDomain)
        saveAgency(config)
        return config
    }

    func enrollWithQRCode(_ content: String) async throws -> AgencyConfig {
        if content.hasPrefix("ORG:") {
            let code = String(content.dropFirst(4))
            return try await enrollWithCode(code)
        }

        throw OnboardingError.invalidQRCode
    }

    private func saveAgency(_ config: AgencyConfig) {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: agencyKey)
        }
        currentAgency = config
        isOnboarded = true
    }

    func clearOnboarding() {
        UserDefaults.standard.removeObject(forKey: agencyKey)
        currentAgency = nil
        isOnboarded = false
    }

    // MARK: - Mock Configs

    private func mockConfigForCode(_ code: String) throws -> AgencyConfig {
        switch code {
        case "SPRINGFIELD", "SPRINGFIELD-PD":
            return AgencyConfig(
                code: "SPRINGFIELD",
                name: "Springfield Police Department",
                apiBaseUrl: "https://redact-1-worker.joelstevick.workers.dev",
                loginIdentifiers: [.badgeNumber, .email],
                primaryColor: "#1E40AF",
                supportEmail: "records@springfieldpd.gov",
                supportPhone: "555-123-4567"
            )

        case "RIVERSIDE", "RIVERSIDE-PD":
            return AgencyConfig(
                code: "RIVERSIDE",
                name: "Riverside Police Department",
                apiBaseUrl: "https://redact-1-worker.joelstevick.workers.dev",
                loginIdentifiers: [.employeeId, .badgeNumber],
                primaryColor: "#059669",
                supportEmail: "foia@riversidepd.org",
                supportPhone: "555-987-6543"
            )

        case "METRO", "METRO-PD":
            return AgencyConfig(
                code: "METRO",
                name: "Metropolitan Police",
                apiBaseUrl: "https://redact-1-worker.joelstevick.workers.dev",
                loginIdentifiers: [.email],
                primaryColor: "#7C3AED",
                supportEmail: "records@metro.gov",
                supportPhone: "555-456-7890"
            )

        case "DEMO", "TEST":
            return .default

        default:
            throw OnboardingError.agencyNotFound
        }
    }

    private func mockConfigForDomain(_ domain: String) throws -> AgencyConfig {
        switch domain {
        case "springfield.gov", "springfieldpd.gov":
            return try mockConfigForCode("SPRINGFIELD")

        case "riverside.gov", "riversidepd.org":
            return try mockConfigForCode("RIVERSIDE")

        case "metro.gov", "metropolice.gov":
            return try mockConfigForCode("METRO")

        case "example.com", "test.com":
            return .default

        default:
            throw OnboardingError.agencyNotFound
        }
    }
}

// MARK: - Onboarding Errors

enum OnboardingError: Error, LocalizedError {
    case invalidEmail
    case invalidQRCode
    case agencyNotFound
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address"
        case .invalidQRCode:
            return "Invalid QR code. Please try again."
        case .agencyNotFound:
            return "Agency not found. Check your code and try again."
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

// MARK: - Enrollment Method

enum EnrollmentMethod: CaseIterable {
    case code
    case email
    case qrCode

    var title: String {
        switch self {
        case .code: return "Code"
        case .email: return "Email"
        case .qrCode: return "QR Code"
        }
    }

    var icon: String {
        switch self {
        case .code: return "number"
        case .email: return "envelope"
        case .qrCode: return "qrcode"
        }
    }
}
