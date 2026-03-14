import XCTest
import SwiftUI
@testable import Redact1

final class ViewTests: XCTestCase {

    // MARK: - StatusBadge Tests

    func testStatusBadgeNew() {
        let badge = StatusBadge(status: .new)
        XCTAssertEqual(badge.status, .new)
        XCTAssertEqual(badge.backgroundColor, .blue)
    }

    func testStatusBadgeProcessing() {
        let badge = StatusBadge(status: .processing)
        XCTAssertEqual(badge.status, .processing)
        XCTAssertEqual(badge.backgroundColor, .orange)
    }

    func testStatusBadgeReview() {
        let badge = StatusBadge(status: .review)
        XCTAssertEqual(badge.status, .review)
        XCTAssertEqual(badge.backgroundColor, .purple)
    }

    func testStatusBadgeExported() {
        let badge = StatusBadge(status: .exported)
        XCTAssertEqual(badge.status, .exported)
        XCTAssertEqual(badge.backgroundColor, .green)
    }

    // MARK: - RequestRow Tests

    func testRequestRowWithValidData() {
        let request = RecordsRequest(
            id: "test-123",
            requestNumber: "FOIA-2024-001",
            title: "Test Request",
            requestDate: 1234567890,
            notes: "Some notes",
            status: .new,
            createdBy: "user-123",
            createdAt: 1234567890,
            updatedAt: 1234567890
        )

        let row = RequestRow(request: request)
        XCTAssertEqual(row.request.id, "test-123")
        XCTAssertEqual(row.request.title, "Test Request")
        XCTAssertEqual(row.request.requestNumber, "FOIA-2024-001")
    }

    // MARK: - AgencyConfig Default Tests

    func testAgencyConfigDefault() {
        let config = AgencyConfig.default

        XCTAssertEqual(config.code, "DEFAULT")
        XCTAssertEqual(config.name, "Default Agency")
        XCTAssertEqual(config.apiBaseUrl, "https://redact-1-worker.joelstevick.workers.dev")
        XCTAssertEqual(config.loginIdentifiers, [.email, .badgeNumber])
        XCTAssertEqual(config.primaryIdentifier, .email)
    }

    // MARK: - RecordsRequest Formatted Date Tests

    func testRecordsRequestFormattedDate() {
        let request = RecordsRequest(
            id: "test-123",
            requestNumber: "FOIA-2024-001",
            title: "Test Request",
            requestDate: 1704067200, // Jan 1, 2024
            notes: nil,
            status: .new,
            createdBy: "user-123",
            createdAt: 1704067200,
            updatedAt: 1704067200
        )

        // The formatted date should be a non-empty string
        XCTAssertFalse(request.formattedDate.isEmpty)
    }

    // MARK: - FileStatus Tests

    func testFileStatusValues() {
        // Test that different file statuses have correct raw values
        XCTAssertEqual(FileStatus.uploaded.rawValue, "uploaded")
        XCTAssertEqual(FileStatus.processing.rawValue, "processing")
        XCTAssertEqual(FileStatus.detected.rawValue, "detected")
        XCTAssertEqual(FileStatus.reviewed.rawValue, "reviewed")
        XCTAssertEqual(FileStatus.exported.rawValue, "exported")
    }

    // MARK: - Detection Type Tests

    func testDetectionTypeDisplayNames() {
        // Test that all detection types have valid display names
        for type in DetectionType.allCases {
            XCTAssertFalse(type.rawValue.isEmpty)
        }
    }

    // MARK: - View Instantiation Tests

    func testLoginViewCanBeCreated() {
        // Verify LoginView can be instantiated
        let view = LoginView()
        XCTAssertNotNil(view)
    }

    func testOnboardingViewCanBeCreated() {
        // Verify OnboardingView can be instantiated with callback
        var callbackCalled = false
        let view = OnboardingView { _ in
            callbackCalled = true
        }
        XCTAssertNotNil(view)
        XCTAssertFalse(callbackCalled) // Callback not called on init
    }

    func testQRScannerViewCanBeCreated() {
        // Verify QRScannerView can be instantiated
        let view = QRScannerView { _ in }
        XCTAssertNotNil(view)
    }

    func testMainTabViewCanBeCreated() {
        // Verify MainTabView can be instantiated
        let view = MainTabView()
        XCTAssertNotNil(view)
    }

    func testRequestListViewCanBeCreated() {
        // Verify RequestListView can be instantiated
        let view = RequestListView()
        XCTAssertNotNil(view)
    }

    func testSettingsViewCanBeCreated() {
        // Verify SettingsView can be instantiated
        let view = SettingsView()
        XCTAssertNotNil(view)
    }

    func testAuditLogViewCanBeCreated() {
        // Verify AuditLogView can be instantiated
        let view = AuditLogView(requestId: "test-123")
        XCTAssertNotNil(view)
    }

    func testExportViewCanBeCreated() {
        // Verify ExportView can be instantiated
        let request = RecordsRequest(
            id: "test-123",
            requestNumber: "FOIA-2024-001",
            title: "Test Request",
            requestDate: 1234567890,
            notes: nil,
            status: .review,
            createdBy: "user-123",
            createdAt: 1234567890,
            updatedAt: 1234567890
        )
        let view = ExportView(request: request, files: [])
        XCTAssertNotNil(view)
    }
}
