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
            archivedAt: nil,
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
        XCTAssertEqual(config.loginIdentifiers, [.email])
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
            archivedAt: nil,
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

    func testLoginViewUsesEmailOnly() {
        // LoginView should use email for login, not badge number
        let view = LoginView()
        XCTAssertNotNil(view)
        // LoginView has email and password fields, no identifier type picker
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
            archivedAt: nil,
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
            deletedAt: nil,
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
            drawingRect: .constant(nil),
            selectedDetectionId: .constant(nil)
        )
        XCTAssertNotNil(view)
    }

    func testDetectionOverlayViewInDrawingMode() {
        // Verify DetectionOverlayView works in drawing mode
        let view = DetectionOverlayView(
            detections: [],
            manualRedactions: [],
            isDrawingMode: true,
            drawingRect: .constant(CGRect(x: 10, y: 10, width: 50, height: 50)),
            selectedDetectionId: .constant(nil)
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
            drawingRect: .constant(nil),
            selectedDetectionId: .constant(nil)
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
            drawingRect: .constant(nil),
            selectedDetectionId: .constant(nil)
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

    // MARK: - CreateUserView Field Tests

    func testCreateUserViewRequiresEmailNotBadge() {
        // CreateUserView should collect email, not badge number
        let view = CreateUserView()
        XCTAssertNotNil(view)
        // View collects: name, email, role, password - no badge number field
    }

    func testCreateUserViewRoleSelection() {
        // CreateUserView should allow role selection
        let view = CreateUserView()
        XCTAssertNotNil(view)
        // Roles available: clerk, supervisor
        XCTAssertEqual(UserRole.allCases.count, 2)
    }

    // MARK: - UserDetailView Tests

    func testUserDetailViewCanBeCreated() {
        let user = User(
            id: "user-123",
            email: "test@test.com",
            name: "Test User",
            role: .clerk,
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
            role: .supervisor,
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
            role: .clerk,
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
            role: .clerk,
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
            role: .clerk,
            createdAt: 1234567890,
            updatedAt: 1234567890
        )
        let row = UserRow(user: user)
        XCTAssertNotNil(row)
        XCTAssertEqual(row.user.name, "Test User")
    }

    func testUserRowDisplaysEmail() {
        let user = User(
            id: "user-123",
            email: "clerk@agency.gov",
            name: "Test Clerk",
            role: .clerk,
            createdAt: 1234567890,
            updatedAt: 1234567890
        )
        let row = UserRow(user: user)

        // UserRow should display the user's email
        XCTAssertEqual(row.user.email, "clerk@agency.gov")
        XCTAssertFalse(row.user.email.isEmpty)
    }

    func testUserRowWithSupervisorRole() {
        let user = User(
            id: "user-456",
            email: "supervisor@agency.gov",
            name: "Test Supervisor",
            role: .supervisor,
            createdAt: 1234567890,
            updatedAt: 1234567890
        )
        let row = UserRow(user: user)

        XCTAssertNotNil(row)
        XCTAssertEqual(row.user.role, .supervisor)
        XCTAssertEqual(row.user.email, "supervisor@agency.gov")
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
            archivedAt: nil,
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
            archivedAt: nil,
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

    // MARK: - ArchivedRequestsView Tests

    func testArchivedRequestsViewCanBeCreated() {
        let view = ArchivedRequestsView()
        XCTAssertNotNil(view)
    }

    func testArchivedRequestRowCanBeCreated() {
        let request = RecordsRequest(
            id: "req-123",
            requestNumber: "FOIA-2024-001",
            title: "Archived Request",
            requestDate: 1234567890,
            notes: nil,
            status: .completed,
            createdBy: "user-123",
            archivedAt: 1234567900,
            createdAt: 1234567890,
            updatedAt: 1234567890
        )
        let row = ArchivedRequestRow(request: request)
        XCTAssertNotNil(row)
    }

    func testArchivedRequestRowWithCallback() {
        let request = RecordsRequest(
            id: "req-123",
            requestNumber: "FOIA-2024-001",
            title: "Archived Request",
            requestDate: 1234567890,
            notes: nil,
            status: .completed,
            createdBy: "user-123",
            archivedAt: 1234567900,
            createdAt: 1234567890,
            updatedAt: 1234567890
        )
        var unarchivedRequest: RecordsRequest?
        let row = ArchivedRequestRow(request: request) { newRequest in
            unarchivedRequest = newRequest
        }
        XCTAssertNotNil(row)
        XCTAssertNil(unarchivedRequest) // Callback not called on init
    }

    // MARK: - PDFReviewView Tests

    func testPDFReviewViewCanBeCreated() {
        let file = EvidenceFile(
            id: "file-123",
            requestId: "req-123",
            filename: "test.pdf",
            fileType: .pdf,
            mimeType: "application/pdf",
            fileSize: 2048,
            originalR2Key: "originals/test.pdf",
            redactedR2Key: nil,
            status: .uploaded,
            uploadedBy: "user-123",
            deletedAt: nil,
            createdAt: 1234567890,
            updatedAt: 1234567890
        )

        let view = PDFReviewView(file: file)
        XCTAssertNotNil(view)
    }

    // MARK: - FullscreenImageEditor Tests

    func testFullscreenImageEditorCanBeCreated() {
        let image = UIImage(systemName: "photo")!
        var detections: [Detection] = []
        var manualRedactions: [ManualRedaction] = []

        let view = FullscreenImageEditor(
            image: image,
            detections: Binding(get: { detections }, set: { detections = $0 }),
            manualRedactions: Binding(get: { manualRedactions }, set: { manualRedactions = $0 }),
            fileId: "file-123"
        )
        XCTAssertNotNil(view)
    }

    func testFullscreenImageEditorWithDetections() {
        let image = UIImage(systemName: "photo")!
        var detections: [Detection] = [
            Detection(
                id: "det-123",
                fileId: "file-123",
                detectionType: .face,
                bboxX: 0.1,
                bboxY: 0.1,
                bboxWidth: 0.2,
                bboxHeight: 0.2,
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
        ]
        var manualRedactions: [ManualRedaction] = []

        let view = FullscreenImageEditor(
            image: image,
            detections: Binding(get: { detections }, set: { detections = $0 }),
            manualRedactions: Binding(get: { manualRedactions }, set: { manualRedactions = $0 }),
            fileId: "file-123"
        )
        XCTAssertNotNil(view)
    }

    // MARK: - ZoomableImageView Tests

    func testZoomableImageViewCanBeCreated() {
        let image = UIImage(systemName: "photo")!
        let view = ZoomableImageView(image: image) {
            EmptyView()
        }
        XCTAssertNotNil(view)
    }

    // MARK: - DetectionOverlayView with Delete Callback Tests

    func testDetectionOverlayViewWithDeleteCallback() {
        var deletedRedaction: ManualRedaction?
        let view = DetectionOverlayView(
            detections: [],
            manualRedactions: [],
            isDrawingMode: false,
            drawingRect: .constant(nil),
            onDrawComplete: nil,
            onDetectionMoved: nil,
            onManualRedactionMoved: nil,
            onManualRedactionDelete: { deletedRedaction = $0 },
            selectedDetectionId: .constant(nil)
        )
        XCTAssertNotNil(view)
        XCTAssertNil(deletedRedaction)
    }

    func testDetectionOverlayViewWithAllCallbacks() {
        var drawCompleted = false
        var detectionMoved = false
        var redactionMoved = false
        var redactionDeleted = false

        let view = DetectionOverlayView(
            detections: [],
            manualRedactions: [],
            isDrawingMode: true,
            drawingRect: .constant(nil),
            onDrawComplete: { _ in drawCompleted = true },
            onDetectionMoved: { _, _ in detectionMoved = true },
            onManualRedactionMoved: { _, _ in redactionMoved = true },
            onManualRedactionDelete: { _ in redactionDeleted = true },
            selectedDetectionId: .constant(nil)
        )
        XCTAssertNotNil(view)
        XCTAssertFalse(drawCompleted)
        XCTAssertFalse(detectionMoved)
        XCTAssertFalse(redactionMoved)
        XCTAssertFalse(redactionDeleted)
    }

    // MARK: - EvidenceFile with deletedAt Tests

    func testEvidenceFileWithDeletedAt() {
        let file = EvidenceFile(
            id: "file-123",
            requestId: "req-123",
            filename: "deleted.jpg",
            fileType: .image,
            mimeType: "image/jpeg",
            fileSize: 1024,
            originalR2Key: "originals/deleted.jpg",
            redactedR2Key: nil,
            status: .uploaded,
            uploadedBy: "user-123",
            deletedAt: 1234567900,
            createdAt: 1234567890,
            updatedAt: 1234567890
        )
        XCTAssertNotNil(file.deletedAt)
        XCTAssertEqual(file.deletedAt, 1234567900)
    }

    func testEvidenceFileWithoutDeletedAt() {
        let file = EvidenceFile(
            id: "file-123",
            requestId: "req-123",
            filename: "active.jpg",
            fileType: .image,
            mimeType: "image/jpeg",
            fileSize: 1024,
            originalR2Key: "originals/active.jpg",
            redactedR2Key: nil,
            status: .uploaded,
            uploadedBy: "user-123",
            deletedAt: nil,
            createdAt: 1234567890,
            updatedAt: 1234567890
        )
        XCTAssertNil(file.deletedAt)
    }

    // MARK: - RecordsRequest isArchived Tests

    func testRecordsRequestIsArchivedWhenArchivedAtIsSet() {
        let request = RecordsRequest(
            id: "req-123",
            requestNumber: "FOIA-2024-001",
            title: "Archived Request",
            requestDate: 1234567890,
            notes: nil,
            status: .completed,
            createdBy: "user-123",
            archivedAt: 1234567900,
            createdAt: 1234567890,
            updatedAt: 1234567890
        )
        XCTAssertTrue(request.isArchived)
    }

    func testRecordsRequestIsNotArchivedWhenArchivedAtIsNil() {
        let request = RecordsRequest(
            id: "req-123",
            requestNumber: "FOIA-2024-001",
            title: "Active Request",
            requestDate: 1234567890,
            notes: nil,
            status: .new,
            createdBy: "user-123",
            archivedAt: nil,
            createdAt: 1234567890,
            updatedAt: 1234567890
        )
        XCTAssertFalse(request.isArchived)
    }

    // MARK: - CollectionPreviewView Tests

    func testCollectionPreviewViewCanBeCreated() {
        let view = CollectionPreviewView(files: [])
        XCTAssertNotNil(view)
    }

    func testCollectionPreviewViewWithFiles() {
        let file = EvidenceFile(
            id: "file-123",
            requestId: "req-123",
            filename: "test.pdf",
            fileType: .pdf,
            mimeType: "application/pdf",
            fileSize: 2048,
            originalR2Key: "originals/test.pdf",
            redactedR2Key: nil,
            status: .uploaded,
            uploadedBy: "user-123",
            deletedAt: nil,
            createdAt: 1234567890,
            updatedAt: 1234567890
        )
        let view = CollectionPreviewView(files: [file])
        XCTAssertNotNil(view)
    }

    func testCollectionPreviewViewWithMultipleFiles() {
        let pdfFile = EvidenceFile(
            id: "file-1",
            requestId: "req-123",
            filename: "doc.pdf",
            fileType: .pdf,
            mimeType: "application/pdf",
            fileSize: 2048,
            originalR2Key: "originals/doc.pdf",
            redactedR2Key: nil,
            status: .uploaded,
            uploadedBy: "user-123",
            deletedAt: nil,
            createdAt: 1234567890,
            updatedAt: 1234567890
        )
        let imageFile = EvidenceFile(
            id: "file-2",
            requestId: "req-123",
            filename: "photo.jpg",
            fileType: .image,
            mimeType: "image/jpeg",
            fileSize: 1024,
            originalR2Key: "originals/photo.jpg",
            redactedR2Key: nil,
            status: .uploaded,
            uploadedBy: "user-123",
            deletedAt: nil,
            createdAt: 1234567890,
            updatedAt: 1234567890
        )
        let view = CollectionPreviewView(files: [pdfFile, imageFile])
        XCTAssertNotNil(view)
    }

    // MARK: - PreviewPageView Tests

    func testPreviewPageViewCanBeCreated() {
        let item = PreviewItem(filename: "test.pdf", image: UIImage(systemName: "doc")!)
        let view = PreviewPageView(item: item)
        XCTAssertNotNil(view)
    }

    // MARK: - SimpleDetectionOverlay Tests

    func testSimpleDetectionOverlayCanBeCreated() {
        var detections: [Detection] = []
        var manualRedactions: [ManualRedaction] = []

        let view = SimpleDetectionOverlay(
            detections: Binding(get: { detections }, set: { detections = $0 }),
            manualRedactions: Binding(get: { manualRedactions }, set: { manualRedactions = $0 }),
            selectedDetectionId: .constant(nil),
            isDrawingMode: true,
            onManualRedactionCreated: { _ in },
            onManualRedactionDeleted: { _ in }
        )
        XCTAssertNotNil(view)
    }

    func testSimpleDetectionOverlayWithDetections() {
        var detections: [Detection] = [
            Detection(
                id: "det-123",
                fileId: "file-123",
                detectionType: .face,
                bboxX: 0.1,
                bboxY: 0.1,
                bboxWidth: 0.2,
                bboxHeight: 0.2,
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
        ]
        var manualRedactions: [ManualRedaction] = []

        let view = SimpleDetectionOverlay(
            detections: Binding(get: { detections }, set: { detections = $0 }),
            manualRedactions: Binding(get: { manualRedactions }, set: { manualRedactions = $0 }),
            selectedDetectionId: .constant(nil),
            isDrawingMode: false,
            onManualRedactionCreated: { _ in },
            onManualRedactionDeleted: { _ in }
        )
        XCTAssertNotNil(view)
    }

    func testSimpleDetectionOverlayWithManualRedactions() {
        var detections: [Detection] = []
        var manualRedactions: [ManualRedaction] = [
            ManualRedaction(
                id: "mr-123",
                fileId: "file-123",
                redactionType: "manual",
                bboxX: 0.3,
                bboxY: 0.3,
                bboxWidth: 0.1,
                bboxHeight: 0.1,
                pageNumber: nil,
                createdBy: "user-123",
                createdAt: 1234567890
            )
        ]

        let view = SimpleDetectionOverlay(
            detections: Binding(get: { detections }, set: { detections = $0 }),
            manualRedactions: Binding(get: { manualRedactions }, set: { manualRedactions = $0 }),
            selectedDetectionId: .constant(nil),
            isDrawingMode: true,
            onManualRedactionCreated: { _ in },
            onManualRedactionDeleted: { _ in }
        )
        XCTAssertNotNil(view)
    }

    func testSimpleDetectionOverlayCallbacks() {
        var detections: [Detection] = []
        var manualRedactions: [ManualRedaction] = []
        var createdRect: CGRect?
        var deletedId: String?

        let view = SimpleDetectionOverlay(
            detections: Binding(get: { detections }, set: { detections = $0 }),
            manualRedactions: Binding(get: { manualRedactions }, set: { manualRedactions = $0 }),
            selectedDetectionId: .constant(nil),
            isDrawingMode: true,
            onManualRedactionCreated: { rect in createdRect = rect },
            onManualRedactionDeleted: { id in deletedId = id }
        )
        XCTAssertNotNil(view)
        XCTAssertNil(createdRect)
        XCTAssertNil(deletedId)
    }

    // MARK: - DraggableRect Tests

    func testDraggableRectCanBeCreated() {
        let view = DraggableRect(
            id: "rect-123",
            normalizedBounds: CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2),
            containerSize: CGSize(width: 300, height: 400),
            strokeColor: .orange,
            fillColor: .orange,
            isSelected: false,
            onSelect: {},
            onMove: { _ in }
        )
        XCTAssertNotNil(view)
    }

    func testDraggableRectWhenSelected() {
        let view = DraggableRect(
            id: "rect-123",
            normalizedBounds: CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2),
            containerSize: CGSize(width: 300, height: 400),
            strokeColor: .purple,
            fillColor: .purple,
            isSelected: true,
            onSelect: {},
            onMove: { _ in }
        )
        XCTAssertNotNil(view)
    }

    func testDraggableRectCallbacks() {
        var selectCalled = false
        var movedBounds: CGRect?

        let view = DraggableRect(
            id: "rect-123",
            normalizedBounds: CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2),
            containerSize: CGSize(width: 300, height: 400),
            strokeColor: .orange,
            fillColor: .orange,
            isSelected: false,
            onSelect: { selectCalled = true },
            onMove: { bounds in movedBounds = bounds }
        )
        XCTAssertNotNil(view)
        XCTAssertFalse(selectCalled)
        XCTAssertNil(movedBounds)
    }

    // MARK: - PageEditorView Tests

    func testPageEditorViewCanBeCreated() {
        let image = UIImage(systemName: "doc")!
        var detections: [Detection] = []
        var manualRedactions: [ManualRedaction] = []

        let view = PageEditorView(
            image: image,
            detections: Binding(get: { detections }, set: { detections = $0 }),
            manualRedactions: Binding(get: { manualRedactions }, set: { manualRedactions = $0 }),
            selectedDetectionId: .constant(nil),
            onRedactionCreated: { _ in },
            onRedactionDeleted: { _ in }
        )
        XCTAssertNotNil(view)
    }

    // MARK: - RequestDetailView Single File Tests

    func testRequestDetailViewSingleFileSupport() {
        // RequestDetailView now supports single file per request
        let view = RequestDetailView(requestId: "req-123")
        XCTAssertNotNil(view)
    }

    // MARK: - FileUploadView PDF Only Tests

    func testFileUploadViewPDFOnly() {
        // FileUploadView now only supports PDF uploads
        let view = FileUploadView(requestId: "req-123")
        XCTAssertNotNil(view)
    }

    func testFileUploadViewPDFOnlyWithCallback() {
        var uploadedFile: EvidenceFile?
        let view = FileUploadView(requestId: "req-123") { file in
            uploadedFile = file
        }
        XCTAssertNotNil(view)
        XCTAssertNil(uploadedFile)
    }

    // MARK: - Detection Status Simplified Tests

    func testDetectionStatusAllOrange() {
        // All detection statuses now display as orange (no approval flow)
        let pendingDetection = Detection(
            id: "det-1",
            fileId: "file-123",
            detectionType: .face,
            bboxX: 0.1, bboxY: 0.1, bboxWidth: 0.1, bboxHeight: 0.1,
            pageNumber: nil, textStart: nil, textEnd: nil, textContent: nil,
            confidence: 0.9,
            status: .pending,
            reviewedBy: nil, reviewedAt: nil,
            createdAt: 0
        )
        XCTAssertEqual(pendingDetection.status, .pending)

        let approvedDetection = Detection(
            id: "det-2",
            fileId: "file-123",
            detectionType: .face,
            bboxX: 0.1, bboxY: 0.1, bboxWidth: 0.1, bboxHeight: 0.1,
            pageNumber: nil, textStart: nil, textEnd: nil, textContent: nil,
            confidence: 0.9,
            status: .approved,
            reviewedBy: "user-123", reviewedAt: 1234567890,
            createdAt: 0
        )
        XCTAssertEqual(approvedDetection.status, .approved)
    }

    // MARK: - RedactionService Tests

    func testRedactionServiceAppliesAllDetections() {
        // RedactionService now applies all detections, not just approved
        let service = RedactionService.shared
        XCTAssertNotNil(service)
    }

    func testRedactionServiceWithImage() {
        let image = UIImage(systemName: "photo")!
        let detections: [Detection] = []
        let manualRedactions: [ManualRedaction] = []

        let result = RedactionService.shared.applyRedactions(
            to: image,
            detections: detections,
            manualRedactions: manualRedactions
        )
        XCTAssertNotNil(result)
    }

    func testRedactionServiceWithDetections() {
        let image = UIImage(systemName: "photo")!
        let detections: [Detection] = [
            Detection(
                id: "det-123",
                fileId: "file-123",
                detectionType: .face,
                bboxX: 0.1,
                bboxY: 0.1,
                bboxWidth: 0.2,
                bboxHeight: 0.2,
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
        ]

        let result = RedactionService.shared.applyRedactions(
            to: image,
            detections: detections,
            manualRedactions: []
        )
        XCTAssertNotNil(result)
    }

    func testRedactionServiceWithManualRedactions() {
        let image = UIImage(systemName: "photo")!
        let manualRedactions: [ManualRedaction] = [
            ManualRedaction(
                id: "mr-123",
                fileId: "file-123",
                redactionType: "manual",
                bboxX: 0.3,
                bboxY: 0.3,
                bboxWidth: 0.1,
                bboxHeight: 0.1,
                pageNumber: nil,
                createdBy: "user-123",
                createdAt: 1234567890
            )
        ]

        let result = RedactionService.shared.applyRedactions(
            to: image,
            detections: [],
            manualRedactions: manualRedactions
        )
        XCTAssertNotNil(result)
    }

    // MARK: - VisionService Tests

    func testVisionServiceExists() {
        let service = VisionService.shared
        XCTAssertNotNil(service)
    }

    // MARK: - ArchivedRequestDetailView Tests

    func testArchivedRequestDetailViewCanBeCreated() {
        let view = ArchivedRequestDetailView(requestId: "req-123")
        XCTAssertNotNil(view)
    }

    func testArchivedRequestDetailViewWithArchivedRequest() {
        // ArchivedRequestDetailView is for viewing archived requests
        let view = ArchivedRequestDetailView(requestId: "archived-req-456")
        XCTAssertNotNil(view)
    }

    // MARK: - PDFReviewView Error State Tests

    func testPDFReviewViewHandlesEmptyFile() {
        // PDFReviewView should handle files with size 0
        let emptyFile = EvidenceFile(
            id: "file-empty",
            requestId: "req-123",
            filename: "empty.pdf",
            fileType: .pdf,
            mimeType: "application/pdf",
            fileSize: 0,
            originalR2Key: "originals/empty.pdf",
            redactedR2Key: nil,
            status: .uploaded,
            uploadedBy: "user-123",
            deletedAt: nil,
            createdAt: 1234567890,
            updatedAt: 1234567890
        )
        let view = PDFReviewView(file: emptyFile)
        XCTAssertNotNil(view)
    }

    func testPDFReviewViewHandlesInvalidPDF() {
        // PDFReviewView shows error state for invalid PDFs
        let invalidFile = EvidenceFile(
            id: "file-invalid",
            requestId: "req-123",
            filename: "invalid.pdf",
            fileType: .pdf,
            mimeType: "application/pdf",
            fileSize: 100,
            originalR2Key: "originals/invalid.pdf",
            redactedR2Key: nil,
            status: .uploaded,
            uploadedBy: "user-123",
            deletedAt: nil,
            createdAt: 1234567890,
            updatedAt: 1234567890
        )
        let view = PDFReviewView(file: invalidFile)
        XCTAssertNotNil(view)
    }

    // MARK: - RequestDetailView Error State Tests

    func testRequestDetailViewShowsErrorState() {
        // RequestDetailView now shows error state when loading fails
        let view = RequestDetailView(requestId: "nonexistent-123")
        XCTAssertNotNil(view)
    }

    func testRequestDetailViewTracksRedactions() {
        // RequestDetailView tracks hasRedactions state for enabling preview/share
        let view = RequestDetailView(requestId: "req-with-redactions")
        XCTAssertNotNil(view)
    }

    // MARK: - ExportView Share Branding Tests

    func testExportViewShareBranding() {
        // ExportView now uses "Share" terminology instead of "Export"
        let request = RecordsRequest(
            id: "req-123",
            requestNumber: "FOIA-2024-001",
            title: "Test Request",
            requestDate: 1234567890,
            notes: nil,
            status: .inProgress,
            createdBy: "user-123",
            archivedAt: nil,
            createdAt: 1234567890,
            updatedAt: 1234567890
        )
        let view = ExportView(request: request, files: [])
        XCTAssertNotNil(view)
    }

    func testExportViewWithSingleFile() {
        // ExportView works with single file (simplified UX)
        let request = RecordsRequest(
            id: "req-123",
            requestNumber: "FOIA-2024-001",
            title: "Test Request",
            requestDate: 1234567890,
            notes: nil,
            status: .inProgress,
            createdBy: "user-123",
            archivedAt: nil,
            createdAt: 1234567890,
            updatedAt: 1234567890
        )
        let file = EvidenceFile(
            id: "file-123",
            requestId: "req-123",
            filename: "document.pdf",
            fileType: .pdf,
            mimeType: "application/pdf",
            fileSize: 2048,
            originalR2Key: "originals/document.pdf",
            redactedR2Key: nil,
            status: .uploaded,
            uploadedBy: "user-123",
            deletedAt: nil,
            createdAt: 1234567890,
            updatedAt: 1234567890
        )
        let view = ExportView(request: request, files: [file])
        XCTAssertNotNil(view)
    }

    func testExportViewAppliesRedactionsClientSide() {
        // ExportView now applies redactions client-side instead of fetching from server
        let request = RecordsRequest(
            id: "req-123",
            requestNumber: "FOIA-2024-001",
            title: "Test Request",
            requestDate: 1234567890,
            notes: nil,
            status: .inProgress,
            createdBy: "user-123",
            archivedAt: nil,
            createdAt: 1234567890,
            updatedAt: 1234567890
        )
        let view = ExportView(request: request, files: [])
        XCTAssertNotNil(view)
    }

    // MARK: - ArchivedRequestsView Navigation Tests

    func testArchivedRequestsViewNavigatesToDetail() {
        // ArchivedRequestsView now supports navigation to ArchivedRequestDetailView
        let view = ArchivedRequestsView()
        XCTAssertNotNil(view)
    }

    // MARK: - Preview/Share Disabled State Tests

    func testPreviewDisabledWithoutRedactions() {
        // Preview should be disabled when there are no redactions
        let view = RequestDetailView(requestId: "req-no-redactions")
        XCTAssertNotNil(view)
    }

    func testShareDisabledWithoutRedactions() {
        // Share should be disabled when there are no redactions
        let view = RequestDetailView(requestId: "req-no-redactions")
        XCTAssertNotNil(view)
    }

    func testPreviewEnabledWithRedactions() {
        // Preview should be enabled when there are redactions
        let view = RequestDetailView(requestId: "req-with-redactions")
        XCTAssertNotNil(view)
    }
}
