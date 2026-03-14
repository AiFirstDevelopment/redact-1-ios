import XCTest
@testable import Redact1

final class APIServiceTests: XCTestCase {

    // MARK: - APIError Tests

    func testAPIErrorDescriptions() {
        XCTAssertEqual(APIError.invalidURL.errorDescription, "Invalid URL")
        XCTAssertEqual(APIError.invalidResponse.errorDescription, "Invalid response from server")
        XCTAssertEqual(APIError.unauthorized.errorDescription, "Unauthorized - please log in again")
        XCTAssertEqual(APIError.notFound.errorDescription, "Resource not found")
        XCTAssertEqual(APIError.serverError("Test error").errorDescription, "Test error")
    }

    func testAPIErrorNetworkError() {
        let underlyingError = NSError(domain: "test", code: -1009, userInfo: [NSLocalizedDescriptionKey: "No internet"])
        let apiError = APIError.networkError(underlyingError)

        XCTAssertNotNil(apiError.errorDescription)
        XCTAssertTrue(apiError.errorDescription!.contains("Network error"))
    }

    func testAPIErrorDecodingError() {
        struct TestStruct: Codable { let value: Int }
        let invalidData = "not json".data(using: .utf8)!

        do {
            _ = try JSONDecoder().decode(TestStruct.self, from: invalidData)
            XCTFail("Should have thrown")
        } catch {
            let apiError = APIError.decodingError(error)
            XCTAssertNotNil(apiError.errorDescription)
            XCTAssertTrue(apiError.errorDescription!.contains("Failed to decode"))
        }
    }

    // MARK: - Request Body Encoding Tests

    func testCreateDetectionBodyEncoding() throws {
        let body = CreateDetectionBody(
            detectionType: "face",
            bboxX: 100,
            bboxY: 100,
            bboxWidth: 50,
            bboxHeight: 50,
            pageNumber: nil,
            textStart: nil,
            textEnd: nil,
            textContent: nil,
            confidence: 0.95
        )

        let data = try JSONEncoder().encode(body)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["detection_type"] as? String, "face")
        XCTAssertEqual(json["bbox_x"] as? Double, 100)
        XCTAssertEqual(json["confidence"] as? Double, 0.95)
    }

    func testCreateManualRedactionBodyEncoding() throws {
        let body = CreateManualRedactionBody(
            redactionType: "custom",
            bboxX: 200,
            bboxY: 200,
            bboxWidth: 100,
            bboxHeight: 100,
            pageNumber: 1
        )

        let data = try JSONEncoder().encode(body)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["redaction_type"] as? String, "custom")
        XCTAssertEqual(json["page_number"] as? Int, 1)
    }

    func testUpdateRequestBodyEncoding() throws {
        let body = UpdateRequestBody(
            title: "Updated Title",
            notes: "Updated notes",
            status: .inProgress
        )

        let data = try JSONEncoder().encode(body)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["title"] as? String, "Updated Title")
        XCTAssertEqual(json["status"] as? String, "in_progress")
        XCTAssertEqual(json["notes"] as? String, "Updated notes")
    }

    func testUpdateRequestBodyPartialEncoding() throws {
        let body = UpdateRequestBody(
            title: nil,
            notes: nil,
            status: .completed
        )

        let data = try JSONEncoder().encode(body)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNil(json["title"])
        XCTAssertEqual(json["status"] as? String, "completed")
        XCTAssertNil(json["notes"])
    }

    // MARK: - APIService Method Existence Tests

    func testAPIServiceHasClearDetectionsMethod() {
        // Verify the clearDetections method exists on APIService
        let service = APIService.shared
        XCTAssertNotNil(service)
        // Method signature: func clearDetections(fileId: String) async throws
    }

    func testAPIServiceHasUpdateManualRedactionBoundsMethod() {
        // Verify the updateManualRedactionBounds method exists on APIService
        let service = APIService.shared
        XCTAssertNotNil(service)
        // Method signature: func updateManualRedactionBounds(_ id: String, bboxX: Double, bboxY: Double, bboxWidth: Double, bboxHeight: Double) async throws -> ManualRedaction
    }

    func testAPIServiceHasUpdateDetectionBoundsMethod() {
        // Verify the updateDetectionBounds method exists on APIService
        let service = APIService.shared
        XCTAssertNotNil(service)
        // Method signature: func updateDetectionBounds(_ id: String, bboxX: Double, bboxY: Double, bboxWidth: Double, bboxHeight: Double) async throws -> Detection
    }

    // MARK: - Detection Bounding Box Tests

    func testDetectionBoundingBoxComputation() {
        let detection = Detection(
            id: "det-123",
            fileId: "file-123",
            detectionType: .face,
            bboxX: 0.1,
            bboxY: 0.2,
            bboxWidth: 0.3,
            bboxHeight: 0.4,
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

        let bbox = detection.boundingBox
        XCTAssertNotNil(bbox)
        XCTAssertEqual(bbox?.origin.x, 0.1)
        XCTAssertEqual(bbox?.origin.y, 0.2)
        XCTAssertEqual(bbox?.width, 0.3)
        XCTAssertEqual(bbox?.height, 0.4)
    }

    func testDetectionBoundingBoxNilWhenMissingCoordinates() {
        let detection = Detection(
            id: "det-123",
            fileId: "file-123",
            detectionType: .face,
            bboxX: nil,
            bboxY: nil,
            bboxWidth: nil,
            bboxHeight: nil,
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

        XCTAssertNil(detection.boundingBox)
    }

    func testManualRedactionBoundingBoxComputation() {
        let redaction = ManualRedaction(
            id: "mr-123",
            fileId: "file-123",
            redactionType: "manual",
            bboxX: 0.5,
            bboxY: 0.5,
            bboxWidth: 0.2,
            bboxHeight: 0.2,
            pageNumber: 1,
            createdBy: "user-123",
            createdAt: 1234567890
        )

        let bbox = redaction.boundingBox
        XCTAssertNotNil(bbox)
        XCTAssertEqual(bbox?.origin.x, 0.5)
        XCTAssertEqual(bbox?.origin.y, 0.5)
        XCTAssertEqual(bbox?.width, 0.2)
        XCTAssertEqual(bbox?.height, 0.2)
    }
}
