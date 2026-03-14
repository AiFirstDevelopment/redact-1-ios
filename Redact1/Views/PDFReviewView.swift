import SwiftUI
import PDFKit

struct PDFReviewView: View {
    let file: EvidenceFile

    @Environment(\.dismiss) private var dismiss
    @State private var pdfDocument: PDFDocument?
    @State private var detections: [Detection] = []
    @State private var manualRedactions: [ManualRedaction] = []
    @State private var currentPage = 0
    @State private var isLoading = false
    @State private var isDetecting = false
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var showingDeleteConfirmation = false
    @State private var showingPreview = false
    @State private var isDrawingMode = false
    @State private var error: String?
    @State private var detectionMessage: String?
    @State private var selectedDetectionId: String?
    @State private var drawingRect: CGRect?
    @State private var showingFullscreen = false

    var pageDetections: [Detection] {
        detections.filter { $0.pageNumber == currentPage + 1 }
    }

    var pageManualRedactions: [ManualRedaction] {
        manualRedactions.filter { $0.pageNumber == currentPage + 1 }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drawing mode hint
            if isDrawingMode {
                HStack {
                    Image(systemName: "hand.draw")
                    Text("Drag on the PDF to draw a redaction box")
                        .font(.caption)
                }
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(Color.purple.opacity(0.2))
                .foregroundStyle(.purple)
            }

            // Detection result message
            if let message = detectionMessage {
                HStack {
                    Image(systemName: message.contains("No") ? "info.circle" : "checkmark.circle.fill")
                    Text(message)
                        .font(.subheadline)
                }
                .padding(10)
                .frame(maxWidth: .infinity)
                .background(message.contains("No") ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
                .foregroundStyle(message.contains("No") ? .orange : .green)
            }

            // PDF View - tap to edit fullscreen
            if let pdfDocument = pdfDocument {
                ZStack {
                    PDFKitView(
                        document: pdfDocument,
                        currentPage: $currentPage,
                        detections: [],
                        manualRedactions: [],
                        isDrawingMode: false,
                        onDrawComplete: nil
                    )

                    // Show detection overlay (non-editable in main view)
                    DetectionOverlayView(
                        detections: pageDetections,
                        manualRedactions: pageManualRedactions,
                        isDrawingMode: false,
                        drawingRect: .constant(nil),
                        onDrawComplete: { _ in },
                        onDetectionMoved: { _, _ in },
                        selectedDetectionId: .constant(nil)
                    )
                    .allowsHitTesting(false)

                    // Tap overlay to enter fullscreen
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showingFullscreen = true
                        }
                }
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
                // Prominent header
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("\(detections.count) items need review")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.15))
                .cornerRadius(8)
                .padding(.horizontal)

                List {
                    // Show page-specific detections if available, otherwise show all
                    let displayDetections = pageDetections.isEmpty ? detections : pageDetections
                    let sectionTitle = pageDetections.isEmpty ? "All Detections" : "Page \(currentPage + 1)"

                    Section(sectionTitle) {
                        ForEach(displayDetections) { detection in
                            HStack {
                                Image(systemName: detection.detectionType.iconName)
                                    .foregroundStyle(statusColor(for: detection.status))

                                VStack(alignment: .leading) {
                                    Text(detection.detectionType.displayName)
                                        .font(.headline)
                                    if let text = detection.textContent {
                                        Text(text)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                    if let page = detection.pageNumber {
                                        Text("Page \(page)")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }

                                Spacer()

                                HStack(spacing: 12) {
                                    Button {
                                        Task { await updateDetection(detection, status: .approved) }
                                    } label: {
                                        Image(systemName: detection.status == .approved ? "checkmark.circle.fill" : "checkmark.circle")
                                            .foregroundStyle(detection.status == .approved ? .green : .gray)
                                    }

                                    Button {
                                        Task { await updateDetection(detection, status: .rejected) }
                                    } label: {
                                        Image(systemName: detection.status == .rejected ? "xmark.circle.fill" : "xmark.circle")
                                            .foregroundStyle(detection.status == .rejected ? .red : .gray)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .frame(height: 250)
            }
        }
        .navigationTitle(file.filename)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .destructive, action: { showingDeleteConfirmation = true }) {
                    if isDeleting {
                        ProgressView()
                    } else {
                        Image(systemName: "trash")
                    }
                }
                .disabled(isDeleting)
                .tint(.red)
            }
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
                .disabled(detections.isEmpty && manualRedactions.isEmpty)
            }
        }
        .confirmationDialog("Delete File", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                deleteFile()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this file? This cannot be undone.")
        }
        .sheet(isPresented: $showingPreview) {
            if let pdfDocument = pdfDocument {
                PDFPreviewView(
                    document: pdfDocument,
                    detections: detections,
                    manualRedactions: manualRedactions
                )
            }
        }
        .alert("Error", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
        .fullScreenCover(isPresented: $showingFullscreen) {
            if let pdfDocument = pdfDocument {
                FullscreenPDFEditor(
                    pdfDocument: pdfDocument,
                    currentPage: $currentPage,
                    detections: $detections,
                    manualRedactions: $manualRedactions,
                    fileId: file.id
                )
            }
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
                // Clear existing detections first
                try await APIService.shared.clearDetections(fileId: file.id)
                await MainActor.run { detections = [] }

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

                await MainActor.run {
                    if !newDetections.isEmpty {
                        let faceCount = newDetections.filter { $0.detectionType == "face" }.count
                        let textCount = newDetections.filter { ["ssn", "phone", "email", "dob"].contains($0.detectionType) }.count
                        var parts: [String] = []
                        if faceCount > 0 { parts.append("\(faceCount) face\(faceCount > 1 ? "s" : "")") }
                        if textCount > 0 { parts.append("\(textCount) text item\(textCount > 1 ? "s" : "")") }
                        if parts.isEmpty { parts.append("\(newDetections.count) item\(newDetections.count > 1 ? "s" : "")") }
                        detectionMessage = "Found \(parts.joined(separator: ", "))"
                    } else {
                        detectionMessage = "No sensitive content detected"
                    }
                }

                if !newDetections.isEmpty {
                    let saved = try await APIService.shared.createDetections(
                        fileId: file.id,
                        detections: newDetections
                    )
                    await MainActor.run {
                        detections = saved
                    }
                }

                // Auto-hide message after 3 seconds
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    detectionMessage = nil
                }
            } catch {
                await MainActor.run {
                    self.error = error.localizedDescription
                }
            }
            await MainActor.run {
                isDetecting = false
            }
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

    private func deleteFile() {
        isDeleting = true
        Task {
            do {
                try await APIService.shared.deleteFile(file.id)
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
            isDeleting = false
        }
    }

    private func handleDrawComplete(_ rect: CGRect) {
        Task {
            do {
                let body = CreateManualRedactionBody(
                    redactionType: "manual",
                    bboxX: Double(rect.origin.x),
                    bboxY: Double(rect.origin.y),
                    bboxWidth: Double(rect.width),
                    bboxHeight: Double(rect.height),
                    pageNumber: currentPage + 1
                )
                let redaction = try await APIService.shared.createManualRedaction(
                    fileId: file.id,
                    body: body
                )
                manualRedactions.append(redaction)
            } catch {
                self.error = error.localizedDescription
            }
        }
        isDrawingMode = false
    }

    private func handleDetectionMoved(_ detection: Detection, _ newRect: CGRect) {
        Task {
            do {
                let updated = try await APIService.shared.updateDetectionBounds(
                    detection.id,
                    bboxX: Double(newRect.origin.x),
                    bboxY: Double(newRect.origin.y),
                    bboxWidth: Double(newRect.width),
                    bboxHeight: Double(newRect.height)
                )
                if let index = detections.firstIndex(where: { $0.id == detection.id }) {
                    detections[index] = updated
                }
            } catch {
                self.error = error.localizedDescription
            }
        }
        selectedDetectionId = nil
    }

    private func statusColor(for status: DetectionStatus) -> Color {
        switch status {
        case .pending: return .orange
        case .approved: return .green
        case .rejected: return .red
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    @Binding var currentPage: Int
    let detections: [Detection]
    let manualRedactions: [ManualRedaction]
    var isDrawingMode: Bool = false
    var onDrawComplete: ((CGRect) -> Void)?

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

            // Remove existing annotations (except built-in ones)
            let existingAnnotations = page.annotations.filter { $0.type == "Square" }
            for annotation in existingAnnotations {
                page.removeAnnotation(annotation)
            }

            let pageBounds = page.bounds(for: .mediaBox)

            // Add detection annotations
            for detection in detections {
                guard detection.pageNumber == currentPage + 1,
                      let bbox = detection.boundingBox else { continue }

                // Convert normalized coordinates to PDF coordinates
                let rect = CGRect(
                    x: bbox.origin.x * pageBounds.width,
                    y: bbox.origin.y * pageBounds.height,
                    width: bbox.width * pageBounds.width,
                    height: bbox.height * pageBounds.height
                )

                let annotation = PDFAnnotation(bounds: rect, forType: .square, withProperties: nil)
                annotation.color = annotationColor(for: detection.status)
                annotation.border = PDFBorder()
                annotation.border?.lineWidth = 2
                page.addAnnotation(annotation)
            }

            // Add manual redaction annotations
            for redaction in manualRedactions {
                guard redaction.pageNumber == currentPage + 1,
                      let bbox = redaction.boundingBox else { continue }

                let rect = CGRect(
                    x: bbox.origin.x * pageBounds.width,
                    y: bbox.origin.y * pageBounds.height,
                    width: bbox.width * pageBounds.width,
                    height: bbox.height * pageBounds.height
                )

                let annotation = PDFAnnotation(bounds: rect, forType: .square, withProperties: nil)
                annotation.color = .purple
                annotation.border = PDFBorder()
                annotation.border?.lineWidth = 2
                page.addAnnotation(annotation)
            }
        }
    }

    private func annotationColor(for status: DetectionStatus) -> UIColor {
        switch status {
        case .pending: return .orange
        case .approved: return .green
        case .rejected: return .red
        }
    }
}

struct PDFPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let document: PDFDocument
    let detections: [Detection]
    let manualRedactions: [ManualRedaction]

    var body: some View {
        NavigationStack {
            VStack {
                if let redactedDoc = RedactionService.shared.applyRedactions(
                    to: document,
                    detections: detections,
                    manualRedactions: manualRedactions
                ) {
                    PDFKitView(
                        document: redactedDoc,
                        currentPage: .constant(0),
                        detections: [],
                        manualRedactions: []
                    )
                } else {
                    Text("Unable to generate preview")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct FullscreenPDFEditor: View {
    @Environment(\.dismiss) private var dismiss
    let pdfDocument: PDFDocument
    @Binding var currentPage: Int
    @Binding var detections: [Detection]
    @Binding var manualRedactions: [ManualRedaction]
    let fileId: String

    @State private var drawingRect: CGRect?
    @State private var selectedDetectionId: String?
    @State private var error: String?

    var pageDetections: [Detection] {
        detections.filter { $0.pageNumber == currentPage + 1 }
    }

    var pageManualRedactions: [ManualRedaction] {
        manualRedactions.filter { $0.pageNumber == currentPage + 1 }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)

                    Spacer()

                    Text("Page \(currentPage + 1) of \(pdfDocument.pageCount)")
                        .foregroundStyle(.white)
                        .font(.headline)

                    Spacer()

                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                        .fontWeight(.semibold)
                }
                .padding()
                .background(Color.black.opacity(0.8))

                // Drawing hint
                HStack {
                    Image(systemName: "hand.draw")
                    Text("Draw to add redaction")
                        .font(.caption)
                }
                .padding(8)
                .foregroundStyle(.purple)
                .background(Color.purple.opacity(0.2))

                // PDF with overlay
                ZStack {
                    PDFKitView(
                        document: pdfDocument,
                        currentPage: $currentPage,
                        detections: [],
                        manualRedactions: [],
                        isDrawingMode: false,
                        onDrawComplete: nil
                    )

                    // Editable detection overlay - always in drawing mode
                    DetectionOverlayView(
                        detections: pageDetections,
                        manualRedactions: pageManualRedactions,
                        isDrawingMode: true,
                        drawingRect: $drawingRect,
                        onDrawComplete: handleDrawComplete,
                        onDetectionMoved: handleDetectionMoved,
                        onManualRedactionMoved: handleManualRedactionMoved,
                        onManualRedactionDelete: handleManualRedactionDelete,
                        selectedDetectionId: $selectedDetectionId
                    )
                }
                .border(Color.purple, width: 2)

                // Page navigation
                if pdfDocument.pageCount > 1 {
                    HStack(spacing: 40) {
                        Button(action: { currentPage = max(0, currentPage - 1) }) {
                            Image(systemName: "chevron.left.circle.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                        }
                        .disabled(currentPage == 0)
                        .opacity(currentPage == 0 ? 0.3 : 1)

                        Button(action: { currentPage = min(pdfDocument.pageCount - 1, currentPage + 1) }) {
                            Image(systemName: "chevron.right.circle.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                        }
                        .disabled(currentPage >= pdfDocument.pageCount - 1)
                        .opacity(currentPage >= pdfDocument.pageCount - 1 ? 0.3 : 1)
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                }
            }

            // Error toast
            if let error = error {
                VStack {
                    Spacer()
                    Text(error)
                        .foregroundStyle(.white)
                        .padding()
                        .background(Color.red.opacity(0.9))
                        .cornerRadius(8)
                        .padding()
                }
            }
        }
    }

    private func handleDrawComplete(_ rect: CGRect) {
        Task {
            do {
                let body = CreateManualRedactionBody(
                    redactionType: "manual",
                    bboxX: Double(rect.origin.x),
                    bboxY: Double(rect.origin.y),
                    bboxWidth: Double(rect.width),
                    bboxHeight: Double(rect.height),
                    pageNumber: currentPage + 1
                )
                let redaction = try await APIService.shared.createManualRedaction(
                    fileId: fileId,
                    body: body
                )
                manualRedactions.append(redaction)
            } catch {
                self.error = error.localizedDescription
            }
        }
        drawingRect = nil
    }

    private func handleDetectionMoved(_ detection: Detection, _ newRect: CGRect) {
        Task {
            do {
                let updated = try await APIService.shared.updateDetectionBounds(
                    detection.id,
                    bboxX: Double(newRect.origin.x),
                    bboxY: Double(newRect.origin.y),
                    bboxWidth: Double(newRect.width),
                    bboxHeight: Double(newRect.height)
                )
                if let index = detections.firstIndex(where: { $0.id == detection.id }) {
                    detections[index] = updated
                }
            } catch {
                self.error = error.localizedDescription
            }
        }
        selectedDetectionId = nil
    }

    private func handleManualRedactionMoved(_ redaction: ManualRedaction, _ newRect: CGRect) {
        Task {
            do {
                let updated = try await APIService.shared.updateManualRedactionBounds(
                    redaction.id,
                    bboxX: Double(newRect.origin.x),
                    bboxY: Double(newRect.origin.y),
                    bboxWidth: Double(newRect.width),
                    bboxHeight: Double(newRect.height)
                )
                if let index = manualRedactions.firstIndex(where: { $0.id == redaction.id }) {
                    manualRedactions[index] = updated
                }
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func handleManualRedactionDelete(_ redaction: ManualRedaction) {
        Task {
            do {
                try await APIService.shared.deleteManualRedaction(redaction.id)
                manualRedactions.removeAll { $0.id == redaction.id }
            } catch {
                self.error = error.localizedDescription
            }
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
            deletedAt: nil,
            createdAt: 0,
            updatedAt: 0
        ))
    }
}
