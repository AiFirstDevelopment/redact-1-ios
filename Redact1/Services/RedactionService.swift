import Foundation
import UIKit
import PDFKit
import CoreGraphics

class RedactionService {
    static let shared = RedactionService()

    private init() {}

    // MARK: - Image Redaction

    func applyRedactions(to image: UIImage, detections: [Detection], manualRedactions: [ManualRedaction]) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let width = cgImage.width
        let height = cgImage.height

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height))

        return renderer.image { context in
            // Draw original image
            let rect = CGRect(x: 0, y: 0, width: width, height: height)
            image.draw(in: rect)

            // Apply all detections
            UIColor.black.setFill()
            for detection in detections {
                if let bbox = detection.boundingBox {
                    // Convert normalized coordinates to pixel coordinates
                    // Vision uses bottom-left origin, UIKit uses top-left
                    let x = bbox.origin.x * CGFloat(width)
                    let y = (1 - bbox.origin.y - bbox.height) * CGFloat(height)
                    let w = bbox.width * CGFloat(width)
                    let h = bbox.height * CGFloat(height)

                    let redactionRect = CGRect(x: x, y: y, width: w, height: h)
                    context.fill(redactionRect)
                }
            }

            // Apply manual redactions
            for redaction in manualRedactions {
                if let bbox = redaction.boundingBox {
                    let x = bbox.origin.x * CGFloat(width)
                    let y = (1 - bbox.origin.y - bbox.height) * CGFloat(height)
                    let w = bbox.width * CGFloat(width)
                    let h = bbox.height * CGFloat(height)

                    let redactionRect = CGRect(x: x, y: y, width: w, height: h)
                    context.fill(redactionRect)
                }
            }
        }
    }

    // MARK: - PDF Redaction

    func applyRedactions(to pdfDocument: PDFDocument, detections: [Detection], manualRedactions: [ManualRedaction]) -> PDFDocument? {
        // Create a new PDF document with redactions applied
        let newDocument = PDFDocument()

        for pageIndex in 0..<pdfDocument.pageCount {
            guard let originalPage = pdfDocument.page(at: pageIndex) else { continue }

            let pageNumber = pageIndex + 1
            let pageRect = originalPage.bounds(for: .mediaBox)

            // Get detections and manual redactions for this page
            let pageDetections = detections.filter { $0.pageNumber == pageNumber }
            let pageManualRedactions = manualRedactions.filter { $0.pageNumber == pageNumber }

            // Render the page to an image, apply redactions, then create new PDF page
            let scale: CGFloat = 2.0
            let scaledSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)

            let renderer = UIGraphicsImageRenderer(size: scaledSize)
            let image = renderer.image { context in
                // White background
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: scaledSize))

                // Draw original page
                context.cgContext.saveGState()
                context.cgContext.translateBy(x: 0, y: scaledSize.height)
                context.cgContext.scaleBy(x: scale, y: -scale)
                originalPage.draw(with: .mediaBox, to: context.cgContext)
                context.cgContext.restoreGState()

                // Apply redactions
                UIColor.black.setFill()

                for detection in pageDetections {
                    if let bbox = detection.boundingBox {
                        let x = bbox.origin.x * scaledSize.width
                        let y = (1 - bbox.origin.y - bbox.height) * scaledSize.height
                        let w = bbox.width * scaledSize.width
                        let h = bbox.height * scaledSize.height
                        context.fill(CGRect(x: x, y: y, width: w, height: h))
                    }
                }

                for redaction in pageManualRedactions {
                    if let bbox = redaction.boundingBox {
                        let x = bbox.origin.x * scaledSize.width
                        let y = (1 - bbox.origin.y - bbox.height) * scaledSize.height
                        let w = bbox.width * scaledSize.width
                        let h = bbox.height * scaledSize.height
                        context.fill(CGRect(x: x, y: y, width: w, height: h))
                    }
                }
            }

            // Create PDF page from image
            if let pdfPage = PDFPage(image: image) {
                newDocument.insert(pdfPage, at: newDocument.pageCount)
            }
        }

        return newDocument
    }

    // MARK: - Export

    func exportImage(_ image: UIImage) -> Data? {
        return image.jpegData(compressionQuality: 0.9)
    }

    func exportPDF(_ pdfDocument: PDFDocument) -> Data? {
        return pdfDocument.dataRepresentation()
    }
}
