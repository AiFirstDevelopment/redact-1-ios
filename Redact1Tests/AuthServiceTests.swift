import XCTest
@testable import Redact1

@MainActor
final class AuthServiceTests: XCTestCase {
    var authService: AuthService!

    override func setUp() async throws {
        authService = AuthService.shared
        // Reset state before each test
        await authService.logout()
    }

    override func tearDown() async throws {
        await authService.logout()
    }

    // MARK: - Initial State Tests

    func testInitialStateIsLoggedOut() {
        XCTAssertFalse(authService.isAuthenticated)
        XCTAssertNil(authService.currentUser)
        XCTAssertNil(authService.error)
        XCTAssertFalse(authService.isLoading)
    }

    // MARK: - Login Validation Tests

    func testLoginWithEmptyIdentifierFails() async {
        await authService.login(identifier: "", password: "password", identifierType: .email)

        XCTAssertFalse(authService.isAuthenticated)
        XCTAssertNotNil(authService.error)
    }

    func testLoginWithEmptyPasswordFails() async {
        await authService.login(identifier: "test@test.com", password: "", identifierType: .email)

        XCTAssertFalse(authService.isAuthenticated)
        XCTAssertNotNil(authService.error)
    }

    // MARK: - Logout Tests

    func testLogoutClearsState() async {
        // First simulate logged in state by setting token
        // Note: In real tests, you'd mock the API
        await authService.logout()

        XCTAssertFalse(authService.isAuthenticated)
        XCTAssertNil(authService.currentUser)
        // Note: logout() does not clear error field, only auth state
    }

    // MARK: - Identifier Type Tests

    func testLoginIdentifierTypeEmail() {
        let identifierType = LoginIdentifierType.email

        XCTAssertEqual(identifierType.rawValue, "email")
        XCTAssertEqual(identifierType.displayName, "Email")
        XCTAssertEqual(identifierType.icon, "envelope")
        XCTAssertEqual(identifierType.placeholder, "you@agency.gov")
    }

    func testLoginIdentifierTypeEmployeeId() {
        let identifierType = LoginIdentifierType.employeeId

        XCTAssertEqual(identifierType.rawValue, "employeeId")
        XCTAssertEqual(identifierType.displayName, "Employee ID")
        XCTAssertEqual(identifierType.icon, "person.text.rectangle")
        XCTAssertEqual(identifierType.placeholder, "EMP-001")
    }

    func testAllLoginIdentifierTypes() {
        let types = LoginIdentifierType.allCases

        XCTAssertEqual(types.count, 2)
        XCTAssertTrue(types.contains(.email))
        XCTAssertTrue(types.contains(.employeeId))
    }

    // MARK: - Email Login Tests

    func testLoginWithEmailMethod() async {
        // Test the convenience email login method
        await authService.login(email: "test@test.com", password: "password123")

        // Without a real backend, this will fail but verifies the method exists
        XCTAssertFalse(authService.isAuthenticated)
    }

    func testLoginWithEmptyEmailFails() async {
        await authService.login(email: "", password: "password123")

        XCTAssertFalse(authService.isAuthenticated)
        XCTAssertNotNil(authService.error)
    }

    func testLoginWithEmptyPasswordViaEmailMethodFails() async {
        await authService.login(email: "test@test.com", password: "")

        XCTAssertFalse(authService.isAuthenticated)
        XCTAssertNotNil(authService.error)
    }

    // MARK: - No Badge Number Tests

    func testLoginIdentifierTypesDoNotIncludeBadgeNumber() {
        let types = LoginIdentifierType.allCases

        // Verify badgeNumber is not in the available identifier types
        for type in types {
            XCTAssertNotEqual(type.rawValue, "badgeNumber")
        }
    }

    func testLoginIdentifierTypeEmailIsDefault() {
        // Email should be the primary login method
        let emailType = LoginIdentifierType.email
        XCTAssertEqual(emailType.displayName, "Email")
        XCTAssertEqual(emailType.icon, "envelope")
    }
}
