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

    // Custom decoding to handle API response format
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(String.self, forKey: .code)
        name = try container.decode(String.self, forKey: .name)
        apiBaseUrl = try container.decode(String.self, forKey: .apiBaseUrl)
        primaryColor = try container.decodeIfPresent(String.self, forKey: .primaryColor)
        supportEmail = try container.decodeIfPresent(String.self, forKey: .supportEmail)
        supportPhone = try container.decodeIfPresent(String.self, forKey: .supportPhone)

        // Decode login identifiers from string array
        let identifierStrings = try container.decode([String].self, forKey: .loginIdentifiers)
        loginIdentifiers = identifierStrings.compactMap { LoginIdentifierType(rawValue: $0) }
    }

    init(code: String, name: String, apiBaseUrl: String, loginIdentifiers: [LoginIdentifierType], primaryColor: String?, supportEmail: String?, supportPhone: String?) {
        self.code = code
        self.name = name
        self.apiBaseUrl = apiBaseUrl
        self.loginIdentifiers = loginIdentifiers
        self.primaryColor = primaryColor
        self.supportEmail = supportEmail
        self.supportPhone = supportPhone
    }
}

// MARK: - Onboarding Service

@MainActor
final class OnboardingService: ObservableObject {
    static let shared = OnboardingService()

    @Published var isOnboarded: Bool = false
    @Published var currentAgency: AgencyConfig?

    private let agencyKey = "redact1_agency_config"
    private let baseUrl = "https://redact-1-worker.joelstevick.workers.dev"

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

        // Fetch from API
        let config = try await fetchAgencyByCode(normalizedCode)
        saveAgency(config)
        return config
    }

    func enrollWithEmail(_ email: String) async throws -> AgencyConfig {
        guard let domain = email.split(separator: "@").last else {
            throw OnboardingError.invalidEmail
        }

        let normalizedDomain = String(domain).lowercased()
        let config = try await fetchAgencyByDomain(normalizedDomain)
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

    // MARK: - API Methods

    private func fetchAgencyByCode(_ code: String) async throws -> AgencyConfig {
        let url = URL(string: "\(baseUrl)/api/agencies/code/\(code)")!

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OnboardingError.networkError("Invalid response")
        }

        if httpResponse.statusCode == 404 {
            throw OnboardingError.agencyNotFound
        }

        guard httpResponse.statusCode == 200 else {
            throw OnboardingError.networkError("Status \(httpResponse.statusCode)")
        }

        let result = try JSONDecoder().decode(AgencyResponse.self, from: data)
        return result.agency
    }

    private func fetchAgencyByDomain(_ domain: String) async throws -> AgencyConfig {
        let url = URL(string: "\(baseUrl)/api/agencies/domain/\(domain)")!

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw OnboardingError.networkError("Invalid response")
        }

        if httpResponse.statusCode == 404 {
            throw OnboardingError.agencyNotFound
        }

        guard httpResponse.statusCode == 200 else {
            throw OnboardingError.networkError("Status \(httpResponse.statusCode)")
        }

        let result = try JSONDecoder().decode(AgencyResponse.self, from: data)
        return result.agency
    }
}

// MARK: - API Response

private struct AgencyResponse: Codable {
    let agency: AgencyConfig
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
