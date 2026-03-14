import XCTest
import UIKit
import PDFKit
@testable import Redact1

final class VisionServiceTests: XCTestCase {

    // MARK: - DetectedRegion Tests

    func testDetectedRegionProperties() {
        let region = DetectedRegion(
            type: .face,
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
            confidence: 0.95,
            textContent: nil,
            pageNumber: nil
        )

        XCTAssertEqual(region.type, .face)
        XCTAssertEqual(region.boundingBox.origin.x, 0.1)
        XCTAssertEqual(region.boundingBox.origin.y, 0.2)
        XCTAssertEqual(region.boundingBox.width, 0.3)
        XCTAssertEqual(region.boundingBox.height, 0.4)
        XCTAssertEqual(region.confidence, 0.95)
        XCTAssertNil(region.textContent)
        XCTAssertNil(region.pageNumber)
    }

    func testDetectedRegionWithTextContent() {
        let region = DetectedRegion(
            type: .ssn,
            boundingBox: .zero,
            confidence: 1.0,
            textContent: "123-45-6789",
            pageNumber: 1
        )

        XCTAssertEqual(region.type, .ssn)
        XCTAssertEqual(region.textContent, "123-45-6789")
        XCTAssertEqual(region.pageNumber, 1)
    }

    // MARK: - VisionError Tests

    func testVisionErrorDescriptions() {
        XCTAssertEqual(VisionError.invalidImage.errorDescription, "Invalid image")
        XCTAssertEqual(VisionError.processingFailed.errorDescription, "Vision processing failed")
    }

    func testVisionErrorConformsToLocalizedError() {
        let error: LocalizedError = VisionError.invalidImage
        XCTAssertNotNil(error.errorDescription)
    }

    // MARK: - VisionService Singleton Tests

    func testVisionServiceSharedInstance() {
        let instance1 = VisionService.shared
        let instance2 = VisionService.shared

        XCTAssertTrue(instance1 === instance2)
    }

    // MARK: - detectInImage Tests

    func testDetectInImageWithNilCGImage() async {
        // Create an empty UIImage that has no cgImage
        let emptyImage = UIImage()

        do {
            _ = try await VisionService.shared.detectInImage(emptyImage)
            XCTFail("Should have thrown invalidImage error")
        } catch let error as VisionError {
            XCTAssertEqual(error, .invalidImage)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testDetectInImageWithValidImage() async throws {
        // Create a simple 100x100 red image
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        let image = renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }

        // Should not crash and should return an array (possibly empty)
        let results = try await VisionService.shared.detectInImage(image)
        XCTAssertNotNil(results)
        // A plain red image should have no faces or text
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Detection Type Tests

    func testAllDetectionTypesHaveRawValues() {
        XCTAssertEqual(DetectionType.face.rawValue, "face")
        XCTAssertEqual(DetectionType.plate.rawValue, "plate")
        XCTAssertEqual(DetectionType.ssn.rawValue, "ssn")
        XCTAssertEqual(DetectionType.phone.rawValue, "phone")
        XCTAssertEqual(DetectionType.email.rawValue, "email")
        XCTAssertEqual(DetectionType.address.rawValue, "address")
        XCTAssertEqual(DetectionType.dob.rawValue, "dob")
    }

    func testAllDetectionTypesHaveDisplayNames() {
        for type in DetectionType.allCases {
            XCTAssertFalse(type.displayName.isEmpty)
        }
    }

    func testAllDetectionTypesHaveIcons() {
        for type in DetectionType.allCases {
            XCTAssertFalse(type.iconName.isEmpty)
        }
    }

    // MARK: - PDF Detection Tests

    func testDetectInPDFWithEmptyDocument() async throws {
        // Create an empty PDF document
        let pdfData = createEmptyPDF()
        guard let pdfDocument = PDFDocument(data: pdfData) else {
            XCTFail("Failed to create PDF document")
            return
        }

        let results = try await VisionService.shared.detectInPDF(pdfDocument)
        XCTAssertNotNil(results)
        // Empty PDF should have no detections
    }

    func testDetectedRegionWithPageNumber() {
        let region = DetectedRegion(
            type: .face,
            boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4),
            confidence: 0.95,
            textContent: nil,
            pageNumber: 2
        )

        XCTAssertEqual(region.pageNumber, 2)
    }

    // MARK: - Helper Methods

    private func createEmptyPDF() -> Data {
        let pdfMetaData = [
            kCGPDFContextCreator: "Test",
            kCGPDFContextAuthor: "Test"
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]

        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)

        let data = renderer.pdfData { context in
            context.beginPage()
            // Empty page
        }
        return data
    }
}
