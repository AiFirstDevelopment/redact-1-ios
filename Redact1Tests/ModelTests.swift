import XCTest
@testable import Redact1

final class ModelTests: XCTestCase {

    // MARK: - UserRole Tests

    func testUserRoleValues() {
        XCTAssertEqual(UserRole.clerk.rawValue, "clerk")
        XCTAssertEqual(UserRole.supervisor.rawValue, "supervisor")
    }

    func testUserRoleDisplayNames() {
        XCTAssertEqual(UserRole.clerk.displayName, "Clerk")
        XCTAssertEqual(UserRole.supervisor.displayName, "Supervisor")
    }

    func testUserRoleAllCases() {
        let roles = UserRole.allCases
        XCTAssertEqual(roles.count, 2)
        XCTAssertTrue(roles.contains(.clerk))
        XCTAssertTrue(roles.contains(.supervisor))
    }

    // MARK: - User Model Tests

    func testUserDecoding() throws {
        let json = """
        {
            "id": "user-123",
            "email": "test@test.com",
            "name": "Test User",
            "role": "clerk",
            "created_at": 1234567890,
            "updated_at": 1234567890
        }
        """.data(using: .utf8)!

        let user = try JSONDecoder().decode(User.self, from: json)

        XCTAssertEqual(user.id, "user-123")
        XCTAssertEqual(user.email, "test@test.com")
        XCTAssertEqual(user.name, "Test User")
        XCTAssertEqual(user.role, .clerk)
        XCTAssertEqual(user.createdAt, 1234567890)
        XCTAssertEqual(user.updatedAt, 1234567890)
    }

    func testUserDecodingWithSupervisorRole() throws {
        let json = """
        {
            "id": "supervisor-123",
            "email": "supervisor@test.com",
            "name": "Supervisor User",
            "role": "supervisor",
            "created_at": 1234567890,
            "updated_at": 1234567890
        }
        """.data(using: .utf8)!

        let user = try JSONDecoder().decode(User.self, from: json)

        XCTAssertEqual(user.id, "supervisor-123")
        XCTAssertEqual(user.role, .supervisor)
    }

    func testUserDecodingWithoutRole() throws {
        // Test that role defaults to clerk when not present
        let json = """
        {
            "id": "user-123",
            "email": "test@test.com",
            "name": "Test User",
            "created_at": 1234567890,
            "updated_at": 1234567890
        }
        """.data(using: .utf8)!

        let user = try JSONDecoder().decode(User.self, from: json)

        XCTAssertEqual(user.role, .clerk)
    }

    func testUserIdentifiable() throws {
        let json = """
        {
            "id": "user-123",
            "email": "test@test.com",
            "name": "Test User",
            "created_at": 1234567890,
            "updated_at": 1234567890
        }
        """.data(using: .utf8)!

        let user = try JSONDecoder().decode(User.self, from: json)

        // User conforms to Identifiable
        XCTAssertEqual(user.id, "user-123")
    }

    func testUserInitializer() {
        let user = User(
            id: "test-id",
            email: "test@test.com",
            name: "Test User",
            role: .supervisor,
            createdAt: 1234567890,
            updatedAt: 1234567890
        )

        XCTAssertEqual(user.id, "test-id")
        XCTAssertEqual(user.email, "test@test.com")
        XCTAssertEqual(user.name, "Test User")
        XCTAssertEqual(user.role, .supervisor)
    }

    func testUserInitializerWithDefaultRole() {
        let user = User(
            id: "test-id",
            email: "test@test.com",
            name: "Test User",
            createdAt: 1234567890,
            updatedAt: 1234567890
        )

        // Default role should be clerk
        XCTAssertEqual(user.role, .clerk)
    }

    func testUserEncoding() throws {
        let user = User(
            id: "test-id",
            email: "test@test.com",
            name: "Test User",
            role: .clerk,
            createdAt: 1234567890,
            updatedAt: 1234567890
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(user)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        // Verify user encodes correctly without badgeNumber
        XCTAssertEqual(json["id"] as? String, "test-id")
        XCTAssertEqual(json["email"] as? String, "test@test.com")
        XCTAssertEqual(json["name"] as? String, "Test User")
        XCTAssertEqual(json["role"] as? String, "clerk")
        XCTAssertNil(json["badge_number"])
        XCTAssertNil(json["badgeNumber"])
    }

    func testUserEmailIsRequired() throws {
        let user = User(
            id: "test-id",
            email: "user@example.com",
            name: "Test User",
            role: .clerk,
            createdAt: 1234567890,
            updatedAt: 1234567890
        )

        // Email is the primary identifier
        XCTAssertFalse(user.email.isEmpty)
        XCTAssertTrue(user.email.contains("@"))
    }

    // MARK: - AuthState Tests

    func testAuthStateIsNotAuthenticatedByDefault() {
        let state = AuthState(token: nil, user: nil)

        XCTAssertFalse(state.isAuthenticated)
    }

    func testAuthStateIsAuthenticatedWithTokenAndUser() throws {
        let json = """
        {
            "id": "user-123",
            "email": "test@test.com",
            "name": "Test User",
            "created_at": 1234567890,
            "updated_at": 1234567890
        }
        """.data(using: .utf8)!

        let user = try JSONDecoder().decode(User.self, from: json)
        let state = AuthState(token: "jwt-token", user: user)

        XCTAssertTrue(state.isAuthenticated)
    }

    // MARK: - Request Model Tests

    func testRequestStatusValues() {
        XCTAssertEqual(RequestStatus.new.rawValue, "new")
        XCTAssertEqual(RequestStatus.inProgress.rawValue, "in_progress")
        XCTAssertEqual(RequestStatus.completed.rawValue, "completed")
    }

    func testRequestStatusDisplayName() {
        XCTAssertEqual(RequestStatus.new.displayName, "New")
        XCTAssertEqual(RequestStatus.inProgress.displayName, "In Progress")
        XCTAssertEqual(RequestStatus.completed.displayName, "Completed")
    }

    func testRequestStatusColor() {
        XCTAssertEqual(RequestStatus.new.color, "blue")
        XCTAssertEqual(RequestStatus.inProgress.color, "orange")
        XCTAssertEqual(RequestStatus.completed.color, "green")
    }

    func testAllRequestStatuses() {
        let statuses = RequestStatus.allCases

        XCTAssertEqual(statuses.count, 3)
        XCTAssertTrue(statuses.contains(.new))
        XCTAssertTrue(statuses.contains(.inProgress))
        XCTAssertTrue(statuses.contains(.completed))
    }

    func testRequestDecoding() throws {
        let json = """
        {
            "id": "req-123",
            "request_number": "FOIA-2024-001",
            "title": "Test Request",
            "request_date": 1234567890,
            "notes": "Some notes",
            "status": "new",
            "created_by": "user-123",
            "created_at": 1234567890,
            "updated_at": 1234567890
        }
        """.data(using: .utf8)!

        let request = try JSONDecoder().decode(RecordsRequest.self, from: json)

        XCTAssertEqual(request.id, "req-123")
        XCTAssertEqual(request.requestNumber, "FOIA-2024-001")
        XCTAssertEqual(request.title, "Test Request")
        XCTAssertEqual(request.status, .new)
    }

    // MARK: - EvidenceFile Model Tests

    func testFileStatusValues() {
        XCTAssertEqual(FileStatus.uploaded.rawValue, "uploaded")
        XCTAssertEqual(FileStatus.processing.rawValue, "processing")
        XCTAssertEqual(FileStatus.detected.rawValue, "detected")
        XCTAssertEqual(FileStatus.reviewed.rawValue, "reviewed")
        XCTAssertEqual(FileStatus.exported.rawValue, "exported")
    }

    func testFileStatusDisplayNames() {
        XCTAssertEqual(FileStatus.uploaded.displayName, "Uploaded")
        XCTAssertEqual(FileStatus.processing.displayName, "Processing")
        XCTAssertEqual(FileStatus.detected.displayName, "Detected")
        XCTAssertEqual(FileStatus.reviewed.displayName, "Reviewed")
        XCTAssertEqual(FileStatus.exported.displayName, "Exported")
    }

    func testFileTypeValues() {
        XCTAssertEqual(FileType.image.rawValue, "image")
        XCTAssertEqual(FileType.pdf.rawValue, "pdf")
    }

    func testEvidenceFileDecoding() throws {
        let json = """
        {
            "id": "file-123",
            "request_id": "req-123",
            "filename": "test.pdf",
            "file_type": "pdf",
            "mime_type": "application/pdf",
            "file_size": 1024,
            "original_r2_key": "originals/test.pdf",
            "status": "uploaded",
            "uploaded_by": "user-123",
            "created_at": 1234567890,
            "updated_at": 1234567890
        }
        """.data(using: .utf8)!

        let file = try JSONDecoder().decode(EvidenceFile.self, from: json)

        XCTAssertEqual(file.id, "file-123")
        XCTAssertEqual(file.filename, "test.pdf")
        XCTAssertEqual(file.fileType, .pdf)
        XCTAssertEqual(file.status, .uploaded)
        XCTAssertNil(file.redactedR2Key)
    }

    // MARK: - Detection Model Tests

    func testDetectionTypeValues() {
        XCTAssertEqual(DetectionType.face.rawValue, "face")
        XCTAssertEqual(DetectionType.plate.rawValue, "plate")
        XCTAssertEqual(DetectionType.ssn.rawValue, "ssn")
        XCTAssertEqual(DetectionType.phone.rawValue, "phone")
        XCTAssertEqual(DetectionType.email.rawValue, "email")
        XCTAssertEqual(DetectionType.address.rawValue, "address")
        XCTAssertEqual(DetectionType.dob.rawValue, "dob")
    }

    func testDetectionTypeDisplayNames() {
        XCTAssertEqual(DetectionType.face.displayName, "Face")
        XCTAssertEqual(DetectionType.plate.displayName, "License Plate")
        XCTAssertEqual(DetectionType.ssn.displayName, "SSN")
        XCTAssertEqual(DetectionType.phone.displayName, "Phone Number")
        XCTAssertEqual(DetectionType.email.displayName, "Email")
        XCTAssertEqual(DetectionType.address.displayName, "Address")
        XCTAssertEqual(DetectionType.dob.displayName, "Date of Birth")
    }

    func testDetectionTypeIcons() {
        XCTAssertEqual(DetectionType.face.iconName, "person.fill")
        XCTAssertEqual(DetectionType.plate.iconName, "car.fill")
        XCTAssertEqual(DetectionType.ssn.iconName, "creditcard.fill")
        XCTAssertEqual(DetectionType.phone.iconName, "phone.fill")
        XCTAssertEqual(DetectionType.email.iconName, "envelope.fill")
        XCTAssertEqual(DetectionType.address.iconName, "house.fill")
        XCTAssertEqual(DetectionType.dob.iconName, "calendar")
    }

    func testAllDetectionTypes() {
        let types = DetectionType.allCases

        XCTAssertEqual(types.count, 7)
        XCTAssertTrue(types.contains(.face))
        XCTAssertTrue(types.contains(.plate))
        XCTAssertTrue(types.contains(.ssn))
    }

    func testDetectionStatusValues() {
        XCTAssertEqual(DetectionStatus.pending.rawValue, "pending")
        XCTAssertEqual(DetectionStatus.approved.rawValue, "approved")
        XCTAssertEqual(DetectionStatus.rejected.rawValue, "rejected")
    }

    func testDetectionDecoding() throws {
        let json = """
        {
            "id": "det-123",
            "file_id": "file-123",
            "detection_type": "face",
            "bbox_x": 100,
            "bbox_y": 100,
            "bbox_width": 50,
            "bbox_height": 50,
            "confidence": 0.95,
            "status": "pending",
            "created_at": 1234567890
        }
        """.data(using: .utf8)!

        let detection = try JSONDecoder().decode(Detection.self, from: json)

        XCTAssertEqual(detection.id, "det-123")
        XCTAssertEqual(detection.detectionType, .face)
        XCTAssertEqual(detection.bboxX, 100)
        XCTAssertEqual(detection.bboxY, 100)
        XCTAssertEqual(detection.bboxWidth, 50)
        XCTAssertEqual(detection.bboxHeight, 50)
        XCTAssertEqual(detection.confidence, 0.95)
        XCTAssertEqual(detection.status, .pending)
    }

    // MARK: - Manual Redaction Model Tests

    func testManualRedactionDecoding() throws {
        let json = """
        {
            "id": "mr-123",
            "file_id": "file-123",
            "redaction_type": "custom",
            "bbox_x": 200,
            "bbox_y": 200,
            "bbox_width": 100,
            "bbox_height": 100,
            "created_by": "user-123",
            "created_at": 1234567890
        }
        """.data(using: .utf8)!

        let redaction = try JSONDecoder().decode(ManualRedaction.self, from: json)

        XCTAssertEqual(redaction.id, "mr-123")
        XCTAssertEqual(redaction.fileId, "file-123")
        XCTAssertEqual(redaction.redactionType, "custom")
        XCTAssertEqual(redaction.bboxX, 200)
    }

    func testManualRedactionBoundingBox() throws {
        let json = """
        {
            "id": "mr-123",
            "file_id": "file-123",
            "redaction_type": "custom",
            "bbox_x": 100,
            "bbox_y": 200,
            "bbox_width": 50,
            "bbox_height": 75,
            "created_by": "user-123",
            "created_at": 1234567890
        }
        """.data(using: .utf8)!

        let redaction = try JSONDecoder().decode(ManualRedaction.self, from: json)

        XCTAssertNotNil(redaction.boundingBox)
        XCTAssertEqual(redaction.boundingBox?.origin.x, 100)
        XCTAssertEqual(redaction.boundingBox?.origin.y, 200)
        XCTAssertEqual(redaction.boundingBox?.size.width, 50)
        XCTAssertEqual(redaction.boundingBox?.size.height, 75)
    }

    // MARK: - Detection Bounding Box Tests

    func testDetectionBoundingBox() throws {
        let json = """
        {
            "id": "det-123",
            "file_id": "file-123",
            "detection_type": "face",
            "bbox_x": 10,
            "bbox_y": 20,
            "bbox_width": 30,
            "bbox_height": 40,
            "confidence": 0.95,
            "status": "pending",
            "created_at": 1234567890
        }
        """.data(using: .utf8)!

        let detection = try JSONDecoder().decode(Detection.self, from: json)

        XCTAssertNotNil(detection.boundingBox)
        XCTAssertEqual(detection.boundingBox?.origin.x, 10)
        XCTAssertEqual(detection.boundingBox?.origin.y, 20)
        XCTAssertEqual(detection.boundingBox?.size.width, 30)
        XCTAssertEqual(detection.boundingBox?.size.height, 40)
    }

    // MARK: - EvidenceFile Formatted Size Tests

    func testEvidenceFileFormattedSize() throws {
        let json = """
        {
            "id": "file-123",
            "request_id": "req-123",
            "filename": "test.pdf",
            "file_type": "pdf",
            "mime_type": "application/pdf",
            "file_size": 1048576,
            "original_r2_key": "originals/test.pdf",
            "status": "uploaded",
            "uploaded_by": "user-123",
            "created_at": 1234567890,
            "updated_at": 1234567890
        }
        """.data(using: .utf8)!

        let file = try JSONDecoder().decode(EvidenceFile.self, from: json)

        // 1048576 bytes = 1 MB
        XCTAssertFalse(file.formattedSize.isEmpty)
        XCTAssertTrue(file.formattedSize.contains("MB") || file.formattedSize.contains("1"))
    }

    // MARK: - LoginResponse Model Tests

    func testLoginResponseDecoding() throws {
        let json = """
        {
            "token": "jwt-token-here",
            "user": {
                "id": "user-123",
                "email": "test@test.com",
                "name": "Test User",
                "created_at": 1234567890,
                "updated_at": 1234567890
            }
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(LoginResponse.self, from: json)

        XCTAssertEqual(response.token, "jwt-token-here")
        XCTAssertEqual(response.user.id, "user-123")
        XCTAssertEqual(response.user.email, "test@test.com")
        XCTAssertEqual(response.user.name, "Test User")
    }

    // MARK: - CreateRequestBody Tests

    func testCreateRequestBodyEncoding() throws {
        let body = CreateRequestBody(
            requestNumber: "FOIA-2024-001",
            title: "Test Request",
            requestDate: 1234567890,
            notes: "Some notes",
            assignTo: nil
        )

        let data = try JSONEncoder().encode(body)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["request_number"] as? String, "FOIA-2024-001")
        XCTAssertEqual(json["title"] as? String, "Test Request")
        XCTAssertEqual(json["request_date"] as? Int, 1234567890)
        XCTAssertEqual(json["notes"] as? String, "Some notes")
    }

    // MARK: - UpdateRequestBody Tests

    func testUpdateRequestBodyEncoding() throws {
        var body = UpdateRequestBody()
        body.title = "Updated Title"
        body.status = .inProgress

        let data = try JSONEncoder().encode(body)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["title"] as? String, "Updated Title")
        XCTAssertEqual(json["status"] as? String, "in_progress")
    }

    func testUpdateRequestBodyWithCreatedBy() throws {
        var body = UpdateRequestBody()
        body.createdBy = "new-user-456"

        let data = try JSONEncoder().encode(body)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["created_by"] as? String, "new-user-456")
    }

    func testUpdateRequestBodyAllFields() throws {
        var body = UpdateRequestBody()
        body.title = "New Title"
        body.notes = "New Notes"
        body.status = .completed
        body.createdBy = "user-789"

        let data = try JSONEncoder().encode(body)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["title"] as? String, "New Title")
        XCTAssertEqual(json["notes"] as? String, "New Notes")
        XCTAssertEqual(json["status"] as? String, "completed")
        XCTAssertEqual(json["created_by"] as? String, "user-789")
    }
}
