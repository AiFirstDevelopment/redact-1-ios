import XCTest
@testable import Redact1

@MainActor
final class OnboardingServiceTests: XCTestCase {
    var onboardingService: OnboardingService!

    override func setUp() async throws {
        onboardingService = OnboardingService.shared
        // Reset state
        onboardingService.clearOnboarding()
    }

    override func tearDown() async throws {
        onboardingService.clearOnboarding()
    }

    // MARK: - Initial State Tests

    func testInitialStateHasNoAgency() {
        XCTAssertNil(onboardingService.currentAgency)
        XCTAssertFalse(onboardingService.isOnboarded)
    }

    // MARK: - Clear Onboarding Tests

    func testClearOnboardingResetsState() {
        onboardingService.clearOnboarding()

        XCTAssertNil(onboardingService.currentAgency)
        XCTAssertFalse(onboardingService.isOnboarded)
    }

    // MARK: - Enrollment Method Tests

    func testEnrollmentMethodCode() {
        let method = EnrollmentMethod.code

        XCTAssertEqual(method.title, "Code")
        XCTAssertEqual(method.icon, "number")
    }

    func testEnrollmentMethodEmail() {
        let method = EnrollmentMethod.email

        XCTAssertEqual(method.title, "Email")
        XCTAssertEqual(method.icon, "envelope")
    }

    func testEnrollmentMethodQRCode() {
        let method = EnrollmentMethod.qrCode

        XCTAssertEqual(method.title, "QR Code")
        XCTAssertEqual(method.icon, "qrcode")
    }

    func testAllEnrollmentMethods() {
        let methods = EnrollmentMethod.allCases

        XCTAssertEqual(methods.count, 3)
        XCTAssertTrue(methods.contains(.code))
        XCTAssertTrue(methods.contains(.email))
        XCTAssertTrue(methods.contains(.qrCode))
    }

    // MARK: - Onboarding Error Tests

    func testOnboardingErrorDescriptions() {
        XCTAssertEqual(OnboardingError.invalidEmail.errorDescription, "Please enter a valid email address")
        XCTAssertEqual(OnboardingError.invalidQRCode.errorDescription, "Invalid QR code. Please try again.")
        XCTAssertEqual(OnboardingError.agencyNotFound.errorDescription, "Agency not found. Check your code and try again.")
        XCTAssertNotNil(OnboardingError.networkError("test").errorDescription)
    }

    // MARK: - Agency Config Tests

    func testAgencyConfigDecoding() throws {
        let json = """
        {
            "code": "DEMO",
            "name": "Demo Police Department",
            "apiBaseUrl": "https://api.example.com",
            "loginIdentifiers": ["email", "employeeId"],
            "primaryColor": "#1a365d",
            "supportEmail": "support@demo.com",
            "supportPhone": "555-1234"
        }
        """.data(using: .utf8)!

        let agency = try JSONDecoder().decode(AgencyConfig.self, from: json)

        XCTAssertEqual(agency.code, "DEMO")
        XCTAssertEqual(agency.name, "Demo Police Department")
        XCTAssertEqual(agency.apiBaseUrl, "https://api.example.com")
        XCTAssertEqual(agency.loginIdentifiers, [.email, .employeeId])
        XCTAssertEqual(agency.primaryColor, "#1a365d")
        XCTAssertEqual(agency.supportEmail, "support@demo.com")
        XCTAssertEqual(agency.supportPhone, "555-1234")
    }

    func testAgencyConfigPrimaryIdentifier() throws {
        let json = """
        {
            "code": "TEST",
            "name": "Test PD",
            "apiBaseUrl": "https://api.example.com",
            "loginIdentifiers": ["employeeId", "email"]
        }
        """.data(using: .utf8)!

        let agency = try JSONDecoder().decode(AgencyConfig.self, from: json)

        // Primary identifier should be the first one
        XCTAssertEqual(agency.primaryIdentifier, .employeeId)
    }

    func testAgencyConfigDefaultPrimaryIdentifier() throws {
        let json = """
        {
            "code": "TEST",
            "name": "Test PD",
            "apiBaseUrl": "https://api.example.com",
            "loginIdentifiers": []
        }
        """.data(using: .utf8)!

        let agency = try JSONDecoder().decode(AgencyConfig.self, from: json)

        // Should default to email when empty
        XCTAssertEqual(agency.primaryIdentifier, .email)
    }

    // MARK: - Email-Only Agency Tests

    func testAgencyConfigWithEmailOnly() throws {
        let json = """
        {
            "code": "EMAIL_ONLY",
            "name": "Email Only Agency",
            "apiBaseUrl": "https://api.example.com",
            "loginIdentifiers": ["email"]
        }
        """.data(using: .utf8)!

        let agency = try JSONDecoder().decode(AgencyConfig.self, from: json)

        XCTAssertEqual(agency.loginIdentifiers.count, 1)
        XCTAssertEqual(agency.loginIdentifiers.first, .email)
        XCTAssertEqual(agency.primaryIdentifier, .email)
    }

    func testAgencyConfigDefaultHasEmailOnly() {
        let defaultConfig = AgencyConfig.default

        // Default agency should only have email login
        XCTAssertEqual(defaultConfig.loginIdentifiers, [.email])
        XCTAssertEqual(defaultConfig.primaryIdentifier, .email)
    }

    func testAgencyConfigDoesNotSupportBadgeNumber() throws {
        let json = """
        {
            "code": "TEST",
            "name": "Test PD",
            "apiBaseUrl": "https://api.example.com",
            "loginIdentifiers": ["email", "employeeId"]
        }
        """.data(using: .utf8)!

        let agency = try JSONDecoder().decode(AgencyConfig.self, from: json)

        // Verify no badge number in identifiers
        for identifier in agency.loginIdentifiers {
            XCTAssertNotEqual(identifier.rawValue, "badgeNumber")
        }
    }

    func testAgencyConfigEquatable() {
        let config1 = AgencyConfig.default
        let config2 = AgencyConfig.default

        XCTAssertEqual(config1, config2)
    }

    // MARK: - Agency Config Optional Fields Tests

    func testAgencyConfigWithoutOptionalFields() throws {
        let json = """
        {
            "code": "MINIMAL",
            "name": "Minimal Agency",
            "apiBaseUrl": "https://api.example.com",
            "loginIdentifiers": ["email"]
        }
        """.data(using: .utf8)!

        let agency = try JSONDecoder().decode(AgencyConfig.self, from: json)

        XCTAssertNil(agency.primaryColor)
        XCTAssertNil(agency.supportEmail)
        XCTAssertNil(agency.supportPhone)
    }
}
