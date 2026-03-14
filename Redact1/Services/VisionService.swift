import Foundation
import Vision
import UIKit
import PDFKit

struct DetectedRegion {
    let type: DetectionType
    let boundingBox: CGRect // Normalized 0-1 coordinates
    let confidence: Float
    let textContent: String?
    let pageNumber: Int?
}

class VisionService {
    static let shared = VisionService()

    private init() {}

    // MARK: - Regex patterns for PII detection

    private let patterns: [(DetectionType, NSRegularExpression)] = {
        var result: [(DetectionType, NSRegularExpression)] = []

        // SSN: 123-45-6789
        if let regex = try? NSRegularExpression(pattern: #"\b\d{3}-\d{2}-\d{4}\b"#) {
            result.append((.ssn, regex))
        }

        // Phone: (123) 456-7890 or 123-456-7890 or 123.456.7890
        if let regex = try? NSRegularExpression(pattern: #"\b(\(\d{3}\)\s?|\d{3}[-.])\d{3}[-.]?\d{4}\b"#) {
            result.append((.phone, regex))
        }

        // Email
        if let regex = try? NSRegularExpression(pattern: #"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"#) {
            result.append((.email, regex))
        }

        // Date of birth: MM/DD/YYYY or MM-DD-YYYY
        if let regex = try? NSRegularExpression(pattern: #"\b(0[1-9]|1[0-2])[/\-](0[1-9]|[12]\d|3[01])[/\-](19|20)\d{2}\b"#) {
            result.append((.dob, regex))
        }

        return result
    }()

    // MARK: - Image Detection

    func detectInImage(_ image: UIImage) async throws -> [DetectedRegion] {
        guard let cgImage = image.cgImage else {
            throw VisionError.invalidImage
        }

        var results: [DetectedRegion] = []

        // Detect faces
        let faceResults = try await detectFaces(in: cgImage)
        results.append(contentsOf: faceResults)

        // Detect text and scan for PII
        let textResults = try await detectText(in: cgImage)
        results.append(contentsOf: textResults)

        return results
    }

    private func detectFaces(in cgImage: CGImage) async throws -> [DetectedRegion] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectFaceRectanglesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                let results = (request.results as? [VNFaceObservation]) ?? []
                let regions = results.map { face in
                    DetectedRegion(
                        type: .face,
                        boundingBox: face.boundingBox,
                        confidence: face.confidence,
                        textContent: nil,
                        pageNumber: nil
                    )
                }
                continuation.resume(returning: regions)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    private func detectText(in cgImage: CGImage) async throws -> [DetectedRegion] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { [weak self] request, error in
                guard let self = self else {
                    continuation.resume(returning: [])
                    return
                }

                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                var regions: [DetectedRegion] = []
                let observations = (request.results as? [VNRecognizedTextObservation]) ?? []

                for observation in observations {
                    guard let candidate = observation.topCandidates(1).first else { continue }
                    let text = candidate.string

                    // Check for PII patterns
                    for (type, regex) in self.patterns {
                        let range = NSRange(text.startIndex..., in: text)
                        let matches = regex.matches(in: text, range: range)

                        for match in matches {
                            if let swiftRange = Range(match.range, in: text) {
                                let matchedText = String(text[swiftRange])
                                regions.append(DetectedRegion(
                                    type: type,
                                    boundingBox: observation.boundingBox,
                                    confidence: candidate.confidence,
                                    textContent: matchedText,
                                    pageNumber: nil
                                ))
                            }
                        }
                    }

                    // Check for license plate pattern (simplified - alphanumeric 5-8 chars)
                    if text.count >= 5 && text.count <= 8 &&
                       text.allSatisfy({ $0.isLetter || $0.isNumber }) &&
                       text.contains(where: { $0.isNumber }) &&
                       text.contains(where: { $0.isLetter }) {
                        regions.append(DetectedRegion(
                            type: .plate,
                            boundingBox: observation.boundingBox,
                            confidence: candidate.confidence,
                            textContent: text,
                            pageNumber: nil
                        ))
                    }
                }

                continuation.resume(returning: regions)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - PDF Detection

    func detectInPDF(_ pdfDocument: PDFDocument) async throws -> [DetectedRegion] {
        var allRegions: [DetectedRegion] = []

        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }

            // Try to get text directly from PDF
            if let text = page.string, !text.isEmpty {
                let textRegions = detectPIIInText(text, pageNumber: pageIndex + 1)
                allRegions.append(contentsOf: textRegions)
            } else {
                // Scanned PDF - render to image and OCR
                let pageRect = page.bounds(for: .mediaBox)
                let scale: CGFloat = 2.0 // Render at 2x for better OCR
                let scaledSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)

                let renderer = UIGraphicsImageRenderer(size: scaledSize)
                let image = renderer.image { context in
                    UIColor.white.setFill()
                    context.fill(CGRect(origin: .zero, size: scaledSize))

                    context.cgContext.translateBy(x: 0, y: scaledSize.height)
                    context.cgContext.scaleBy(x: scale, y: -scale)

                    page.draw(with: .mediaBox, to: context.cgContext)
                }

                if let cgImage = image.cgImage {
                    let textResults = try await detectText(in: cgImage)
                    let adjustedResults = textResults.map { region in
                        DetectedRegion(
                            type: region.type,
                            boundingBox: region.boundingBox,
                            confidence: region.confidence,
                            textContent: region.textContent,
                            pageNumber: pageIndex + 1
                        )
                    }
                    allRegions.append(contentsOf: adjustedResults)
                }
            }
        }

        return allRegions
    }

    private func detectPIIInText(_ text: String, pageNumber: Int) -> [DetectedRegion] {
        var regions: [DetectedRegion] = []

        for (type, regex) in patterns {
            let range = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, range: range)

            for match in matches {
                if let swiftRange = Range(match.range, in: text) {
                    let matchedText = String(text[swiftRange])

                    // For text-based PDFs, we don't have bounding boxes
                    // We'll store text position instead
                    regions.append(DetectedRegion(
                        type: type,
                        boundingBox: .zero, // Will be computed when rendering
                        confidence: 1.0,
                        textContent: matchedText,
                        pageNumber: pageNumber
                    ))
                }
            }
        }

        return regions
    }
}

enum VisionError: Error, LocalizedError {
    case invalidImage
    case processingFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Invalid image"
        case .processingFailed: return "Vision processing failed"
        }
    }
}
