import SwiftUI
import PDFKit

struct PDFReviewView: View {
    let file: EvidenceFile

    @State private var pdfDocument: PDFDocument?
    @State private var detections: [Detection] = []
    @State private var manualRedactions: [ManualRedaction] = []
    @State private var currentPage = 0
    @State private var isLoading = false
    @State private var isDetecting = false
    @State private var isSaving = false
    @State private var error: String?

    var pageDetections: [Detection] {
        detections.filter { $0.pageNumber == currentPage + 1 }
    }

    var pageManualRedactions: [ManualRedaction] {
        manualRedactions.filter { $0.pageNumber == currentPage + 1 }
    }

    var body: some View {
        VStack(spacing: 0) {
            // PDF View
            if let pdfDocument = pdfDocument {
                PDFKitView(
                    document: pdfDocument,
                    currentPage: $currentPage,
                    detections: pageDetections,
                    manualRedactions: pageManualRedactions
                )
            } else if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Page navigation
            if let pdfDocument = pdfDocument, pdfDocument.pageCount > 1 {
                HStack {
                    Button(action: { currentPage = max(0, currentPage - 1) }) {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(currentPage == 0)

                    Text("Page \(currentPage + 1) of \(pdfDocument.pageCount)")
                        .font(.caption)

                    Button(action: { currentPage = min(pdfDocument.pageCount - 1, currentPage + 1) }) {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(currentPage >= pdfDocument.pageCount - 1)
                }
                .padding()
                .background(Color(.systemGray6))
            }

            // Detection list
            if !detections.isEmpty {
                List {
                    Section("Detections (Page \(currentPage + 1))") {
                        ForEach(pageDetections) { detection in
                            DetectionRow(detection: detection) { newStatus in
                                Task {
                                    await updateDetection(detection, status: newStatus)
                                }
                            }
                        }
                    }
                }
                .frame(height: 200)
            }
        }
        .navigationTitle(file.filename)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(action: runDetection) {
                    if isDetecting {
                        ProgressView()
                    } else {
                        Image(systemName: "wand.and.stars")
                    }
                }
                .disabled(pdfDocument == nil || isDetecting)

                Button(action: saveReview) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Image(systemName: "checkmark.circle")
                    }
                }
                .disabled(detections.isEmpty)
            }
        }
        .alert("Error", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
        .task {
            await loadPDF()
            await loadDetections()
        }
    }

    private func loadPDF() async {
        isLoading = true
        do {
            let data = try await APIService.shared.getFileOriginal(file.id)
            if let document = PDFDocument(data: data) {
                pdfDocument = document
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func loadDetections() async {
        do {
            let result = try await APIService.shared.listDetections(fileId: file.id)
            detections = result.detections
            manualRedactions = result.manualRedactions
        } catch {
            // Ignore - no existing detections
        }
    }

    private func runDetection() {
        guard let pdfDocument = pdfDocument else { return }

        isDetecting = true
        Task {
            do {
                let regions = try await VisionService.shared.detectInPDF(pdfDocument)

                let newDetections = regions.map { region in
                    CreateDetectionBody(
                        detectionType: region.type.rawValue,
                        bboxX: Double(region.boundingBox.origin.x),
                        bboxY: Double(region.boundingBox.origin.y),
                        bboxWidth: Double(region.boundingBox.width),
                        bboxHeight: Double(region.boundingBox.height),
                        pageNumber: region.pageNumber,
                        textStart: nil,
                        textEnd: nil,
                        textContent: region.textContent,
                        confidence: Double(region.confidence)
                    )
                }

                if !newDetections.isEmpty {
                    detections = try await APIService.shared.createDetections(
                        fileId: file.id,
                        detections: newDetections
                    )
                }
            } catch {
                self.error = error.localizedDescription
            }
            isDetecting = false
        }
    }

    private func updateDetection(_ detection: Detection, status: DetectionStatus) async {
        do {
            let updated = try await APIService.shared.updateDetection(detection.id, status: status)
            if let index = detections.firstIndex(where: { $0.id == detection.id }) {
                detections[index] = updated
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func saveReview() {
        guard let pdfDocument = pdfDocument else { return }

        isSaving = true
        Task {
            do {
                guard let redactedDocument = RedactionService.shared.applyRedactions(
                    to: pdfDocument,
                    detections: detections,
                    manualRedactions: manualRedactions
                ) else {
                    throw RedactionError.failed
                }

                guard let pdfData = RedactionService.shared.exportPDF(redactedDocument) else {
                    throw RedactionError.exportFailed
                }

                try await APIService.shared.uploadRedactedFile(
                    file.id,
                    data: pdfData,
                    mimeType: "application/pdf"
                )
            } catch {
                self.error = error.localizedDescription
            }
            isSaving = false
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    @Binding var currentPage: Int
    let detections: [Detection]
    let manualRedactions: [ManualRedaction]

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        if let page = document.page(at: currentPage) {
            pdfView.go(to: page)
        }
    }
}

#Preview {
    NavigationStack {
        PDFReviewView(file: EvidenceFile(
            id: "test",
            requestId: "req",
            filename: "test.pdf",
            fileType: .pdf,
            mimeType: "application/pdf",
            fileSize: 1000,
            originalR2Key: "key",
            redactedR2Key: nil,
            status: .uploaded,
            uploadedBy: "user",
            createdAt: 0,
            updatedAt: 0
        ))
    }
}
