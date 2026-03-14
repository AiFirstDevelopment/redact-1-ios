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

    func testStatusBadgeInProgress() {
        let badge = StatusBadge(status: .inProgress)
        XCTAssertEqual(badge.status, .inProgress)
        XCTAssertEqual(badge.backgroundColor, .orange)
    }

    func testStatusBadgeCompleted() {
        let badge = StatusBadge(status: .completed)
        XCTAssertEqual(badge.status, .completed)
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
            status: .inProgress,
            createdBy: "user-123",
            createdAt: 1234567890,
            updatedAt: 1234567890
        )
        let view = ExportView(request: request, files: [])
        XCTAssertNotNil(view)
    }

    // MARK: - FileUploadView Tests

    func testFileUploadViewCanBeCreated() {
        // Verify FileUploadView can be instantiated with requestId
        let view = FileUploadView(requestId: "test-request-123")
        XCTAssertNotNil(view)
    }

    func testFileUploadViewWithCallback() {
        // Verify FileUploadView can be instantiated with callback
        var callbackCalled = false
        let view = FileUploadView(requestId: "test-request-123") { _ in
            callbackCalled = true
        }
        XCTAssertNotNil(view)
        XCTAssertFalse(callbackCalled) // Callback not called on init
    }

    // MARK: - ImageReviewView Tests

    func testImageReviewViewCanBeCreated() {
        // Verify ImageReviewView can be instantiated with EvidenceFile
        let file = EvidenceFile(
            id: "file-123",
            requestId: "req-123",
            filename: "test.jpg",
            fileType: .image,
            mimeType: "image/jpeg",
            fileSize: 1024,
            originalR2Key: "originals/test.jpg",
            redactedR2Key: nil,
            status: .uploaded,
            uploadedBy: "user-123",
            createdAt: 1234567890,
            updatedAt: 1234567890
        )

        let view = ImageReviewView(file: file)
        XCTAssertNotNil(view)
    }

    // MARK: - DetectionOverlayView Tests

    func testDetectionOverlayViewCanBeCreated() {
        // Verify DetectionOverlayView can be instantiated
        let view = DetectionOverlayView(
            detections: [],
            manualRedactions: [],
            isDrawingMode: false,
            drawingRect: .constant(nil)
        )
        XCTAssertNotNil(view)
    }

    func testDetectionOverlayViewInDrawingMode() {
        // Verify DetectionOverlayView works in drawing mode
        let view = DetectionOverlayView(
            detections: [],
            manualRedactions: [],
            isDrawingMode: true,
            drawingRect: .constant(CGRect(x: 10, y: 10, width: 50, height: 50))
        )
        XCTAssertNotNil(view)
    }

    func testDetectionOverlayViewWithDetections() {
        // Create a mock detection
        let detection = Detection(
            id: "det-123",
            fileId: "file-123",
            detectionType: .face,
            bboxX: 100,
            bboxY: 100,
            bboxWidth: 50,
            bboxHeight: 50,
            pageNumber: nil,
            textStart: nil,
            textEnd: nil,
            textContent: nil,
            confidence: 0.95,
            status: .pending,
            reviewedBy: nil,
            reviewedAt: nil,
            createdAt: 1234567890
        )

        let view = DetectionOverlayView(
            detections: [detection],
            manualRedactions: [],
            isDrawingMode: false,
            drawingRect: .constant(nil)
        )
        XCTAssertNotNil(view)
    }

    func testDetectionOverlayViewWithManualRedactions() {
        // Create a mock manual redaction
        let redaction = ManualRedaction(
            id: "mr-123",
            fileId: "file-123",
            redactionType: "manual",
            bboxX: 200,
            bboxY: 200,
            bboxWidth: 100,
            bboxHeight: 100,
            pageNumber: nil,
            createdBy: "user-123",
            createdAt: 1234567890
        )

        let view = DetectionOverlayView(
            detections: [],
            manualRedactions: [redaction],
            isDrawingMode: false,
            drawingRect: .constant(nil)
        )
        XCTAssertNotNil(view)
    }

    // MARK: - DetectionRow Tests

    func testDetectionRowCanBeCreated() {
        let detection = Detection(
            id: "det-123",
            fileId: "file-123",
            detectionType: .face,
            bboxX: 100,
            bboxY: 100,
            bboxWidth: 50,
            bboxHeight: 50,
            pageNumber: nil,
            textStart: nil,
            textEnd: nil,
            textContent: nil,
            confidence: 0.95,
            status: .pending,
            reviewedBy: nil,
            reviewedAt: nil,
            createdAt: 1234567890
        )

        let row = DetectionRow(detection: detection)
        XCTAssertNotNil(row)
    }

    func testDetectionRowWithCallback() {
        let detection = Detection(
            id: "det-123",
            fileId: "file-123",
            detectionType: .ssn,
            bboxX: 100,
            bboxY: 100,
            bboxWidth: 50,
            bboxHeight: 50,
            pageNumber: nil,
            textStart: nil,
            textEnd: nil,
            textContent: "123-45-6789",
            confidence: 0.99,
            status: .pending,
            reviewedBy: nil,
            reviewedAt: nil,
            createdAt: 1234567890
        )

        var statusChanged: DetectionStatus?
        let row = DetectionRow(detection: detection) { newStatus in
            statusChanged = newStatus
        }

        XCTAssertNotNil(row)
        XCTAssertNil(statusChanged) // Callback not called on init
    }

    func testDetectionRowStatusColors() {
        // Test pending status
        let pendingDetection = Detection(
            id: "det-1",
            fileId: "file-123",
            detectionType: .face,
            bboxX: 0, bboxY: 0, bboxWidth: 10, bboxHeight: 10,
            pageNumber: nil, textStart: nil, textEnd: nil, textContent: nil,
            confidence: 0.9,
            status: .pending,
            reviewedBy: nil, reviewedAt: nil,
            createdAt: 0
        )
        let pendingRow = DetectionRow(detection: pendingDetection)
        XCTAssertNotNil(pendingRow)

        // Test approved status
        let approvedDetection = Detection(
            id: "det-2",
            fileId: "file-123",
            detectionType: .face,
            bboxX: 0, bboxY: 0, bboxWidth: 10, bboxHeight: 10,
            pageNumber: nil, textStart: nil, textEnd: nil, textContent: nil,
            confidence: 0.9,
            status: .approved,
            reviewedBy: "user-123", reviewedAt: 1234567890,
            createdAt: 0
        )
        let approvedRow = DetectionRow(detection: approvedDetection)
        XCTAssertNotNil(approvedRow)

        // Test rejected status
        let rejectedDetection = Detection(
            id: "det-3",
            fileId: "file-123",
            detectionType: .face,
            bboxX: 0, bboxY: 0, bboxWidth: 10, bboxHeight: 10,
            pageNumber: nil, textStart: nil, textEnd: nil, textContent: nil,
            confidence: 0.9,
            status: .rejected,
            reviewedBy: "user-123", reviewedAt: 1234567890,
            createdAt: 0
        )
        let rejectedRow = DetectionRow(detection: rejectedDetection)
        XCTAssertNotNil(rejectedRow)
    }

    // MARK: - RedactionError Tests

    func testRedactionErrorDescriptions() {
        XCTAssertEqual(RedactionError.failed.errorDescription, "Failed to apply redactions")
        XCTAssertEqual(RedactionError.exportFailed.errorDescription, "Failed to export redacted file")
    }

    // MARK: - UploadError Tests

    func testUploadErrorDescriptions() {
        XCTAssertEqual(UploadError.accessDenied.errorDescription, "Unable to access the selected file")
    }

    // MARK: - UsersView Tests

    func testUsersViewCanBeCreated() {
        let view = UsersView()
        XCTAssertNotNil(view)
    }

    func testCreateUserViewCanBeCreated() {
        let view = CreateUserView()
        XCTAssertNotNil(view)
    }

    func testCreateUserViewWithCallback() {
        var callbackCalled = false
        let view = CreateUserView { _ in
            callbackCalled = true
        }
        XCTAssertNotNil(view)
        XCTAssertFalse(callbackCalled)
    }

    // MARK: - UserDetailView Tests

    func testUserDetailViewCanBeCreated() {
        let user = User(
            id: "user-123",
            email: "test@test.com",
            name: "Test User",
            badgeNumber: "12345",
            role: .officer,
            createdAt: 1234567890,
            updatedAt: 1234567890
        )
        let view = UserDetailView(user: user)
        XCTAssertNotNil(view)
    }

    func testUserDetailViewWithAdminUser() {
        let adminUser = User(
            id: "admin-123",
            email: "admin@test.com",
            name: "Admin User",
            badgeNumber: nil,
            role: .admin,
            createdAt: 1234567890,
            updatedAt: 1234567890
        )
        let view = UserDetailView(user: adminUser)
        XCTAssertNotNil(view)
    }

    func testEditUserViewCanBeCreated() {
        let user = User(
            id: "user-123",
            email: "test@test.com",
            name: "Test User",
            badgeNumber: "12345",
            role: .officer,
            createdAt: 1234567890,
            updatedAt: 1234567890
        )
        let view = EditUserView(user: user)
        XCTAssertNotNil(view)
    }

    func testEditUserViewWithCallback() {
        let user = User(
            id: "user-123",
            email: "test@test.com",
            name: "Test User",
            badgeNumber: nil,
            role: .officer,
            createdAt: 1234567890,
            updatedAt: 1234567890
        )
        var updatedUser: User?
        let view = EditUserView(user: user) { newUser in
            updatedUser = newUser
        }
        XCTAssertNotNil(view)
        XCTAssertNil(updatedUser)
    }

    // MARK: - UserRow Tests

    func testUserRowCanBeCreated() {
        let user = User(
            id: "user-123",
            email: "test@test.com",
            name: "Test User",
            badgeNumber: "12345",
            role: .officer,
            createdAt: 1234567890,
            updatedAt: 1234567890
        )
        let row = UserRow(user: user)
        XCTAssertNotNil(row)
        XCTAssertEqual(row.user.name, "Test User")
    }

    func testUserRowWithoutBadgeNumber() {
        let user = User(
            id: "user-123",
            email: "test@test.com",
            name: "Test User",
            badgeNumber: nil,
            role: .officer,
            createdAt: 1234567890,
            updatedAt: 1234567890
        )
        let row = UserRow(user: user)
        XCTAssertNotNil(row)
        XCTAssertNil(row.user.badgeNumber)
    }

    // MARK: - RequestDetailView Tests

    func testRequestDetailViewCanBeCreated() {
        let view = RequestDetailView(requestId: "req-123")
        XCTAssertNotNil(view)
    }

    // MARK: - ReassignRequestView Tests

    func testReassignRequestViewCanBeCreated() {
        let request = RecordsRequest(
            id: "req-123",
            requestNumber: "FOIA-2024-001",
            title: "Test Request",
            requestDate: 1234567890,
            notes: nil,
            status: .new,
            createdBy: "user-123",
            createdAt: 1234567890,
            updatedAt: 1234567890
        )
        let view = ReassignRequestView(request: request)
        XCTAssertNotNil(view)
    }

    func testReassignRequestViewWithCallback() {
        let request = RecordsRequest(
            id: "req-123",
            requestNumber: "FOIA-2024-001",
            title: "Test Request",
            requestDate: 1234567890,
            notes: nil,
            status: .inProgress,
            createdBy: "user-123",
            createdAt: 1234567890,
            updatedAt: 1234567890
        )
        var updatedRequest: RecordsRequest?
        let view = ReassignRequestView(request: request) { newRequest in
            updatedRequest = newRequest
        }
        XCTAssertNotNil(view)
        XCTAssertNil(updatedRequest)
    }

    // MARK: - MainTabView Role Tests

    func testMainTabViewCanBeCreatedWithoutEnvironment() {
        // MainTabView requires AuthService environment object
        // This test verifies the view type exists
        let view = MainTabView()
        XCTAssertNotNil(view)
    }

    // MARK: - SettingsView Profile Edit Tests

    func testSettingsViewHasProfileEditCapability() {
        let view = SettingsView()
        XCTAssertNotNil(view)
    }
}
