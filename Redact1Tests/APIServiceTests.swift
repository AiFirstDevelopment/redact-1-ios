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
            status: .review
        )

        let data = try JSONEncoder().encode(body)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertEqual(json["title"] as? String, "Updated Title")
        XCTAssertEqual(json["status"] as? String, "review")
        XCTAssertEqual(json["notes"] as? String, "Updated notes")
    }

    func testUpdateRequestBodyPartialEncoding() throws {
        let body = UpdateRequestBody(
            title: nil,
            notes: nil,
            status: .exported
        )

        let data = try JSONEncoder().encode(body)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        XCTAssertNil(json["title"])
        XCTAssertEqual(json["status"] as? String, "exported")
        XCTAssertNil(json["notes"])
    }
}
