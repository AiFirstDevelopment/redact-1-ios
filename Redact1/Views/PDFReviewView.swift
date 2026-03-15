import SwiftUI
import PDFKit

struct PDFReviewView: View {
    let file: EvidenceFile

    @Environment(\.dismiss) private var dismiss
    @State private var pdfDocument: PDFDocument?
    @State private var pageImages: [UIImage] = []
    @State private var detections: [Detection] = []
    @State private var manualRedactions: [ManualRedaction] = []
    @State private var currentPage = 0
    @State private var isLoading = false
    @State private var isDetecting = false
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var showingDeleteConfirmation = false
    @State private var error: String?
    @State private var selectedDetectionId: String?

    // Track modifications for API sync
    @State private var modifiedDetectionIds: Set<String> = []
    @State private var modifiedRedactionIds: Set<String> = []
    @State private var newRedactionIds: Set<String> = []
    @State private var deletedRedactionIds: Set<String> = []

    var pageDetections: [Detection] {
        detections.filter { $0.pageNumber == currentPage + 1 }
    }

    var pageManualRedactions: [ManualRedaction] {
        manualRedactions.filter { $0.pageNumber == currentPage + 1 }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if isLoading {
                ProgressView("Loading...")
                    .tint(.white)
                    .foregroundStyle(.white)
            } else if !pageImages.isEmpty {
                // Main content - swipeable pages with overlay
                TabView(selection: $currentPage) {
                    ForEach(0..<pageImages.count, id: \.self) { pageIndex in
                        PageEditorView(
                            image: pageImages[pageIndex],
                            detections: detectionsBinding(for: pageIndex),
                            manualRedactions: redactionsBinding(for: pageIndex),
                            selectedDetectionId: $selectedDetectionId,
                            onRedactionCreated: { bounds in
                                addManualRedaction(bounds: bounds, page: pageIndex + 1)
                            },
                            onRedactionDeleted: { id in
                                deleteManualRedaction(id: id)
                            }
                        )
                        .tag(pageIndex)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Top toolbar
                VStack {
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .padding(12)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                        }

                        Spacer()

                        HStack(spacing: 12) {
                            Button(action: { withAnimation { currentPage -= 1 } }) {
                                Image(systemName: "chevron.left")
                                    .font(.body.weight(.semibold))
                            }
                            .opacity(currentPage > 0 ? 1 : 0.3)
                            .disabled(currentPage == 0)

                            Text("Page \(currentPage + 1) of \(pageImages.count)")

                            Button(action: { withAnimation { currentPage += 1 } }) {
                                Image(systemName: "chevron.right")
                                    .font(.body.weight(.semibold))
                            }
                            .opacity(currentPage < pageImages.count - 1 ? 1 : 0.3)
                            .disabled(currentPage >= pageImages.count - 1)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.black.opacity(0.5)))
                        .gesture(
                            DragGesture(minimumDistance: 30)
                                .onEnded { value in
                                    withAnimation {
                                        if value.translation.width < 0 && currentPage < pageImages.count - 1 {
                                            currentPage += 1
                                        } else if value.translation.width > 0 && currentPage > 0 {
                                            currentPage -= 1
                                        }
                                    }
                                }
                        )

                        Spacer()

                        // Save button
                        Button(action: saveChanges) {
                            Image(systemName: "checkmark")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .padding(12)
                                .background(Circle().fill(Color.green.opacity(0.8)))
                        }
                        .disabled(isSaving)
                    }
                    .padding()

                    Spacer()

                    // Bottom toolbar
                    HStack(spacing: 20) {
                        // Delete file
                        Button(action: { showingDeleteConfirmation = true }) {
                            VStack {
                                Image(systemName: "trash")
                                Text("Delete")
                                    .font(.caption)
                            }
                            .foregroundStyle(.red)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.5)))
                        }

                        // Drawing hint
                        VStack {
                            Image(systemName: "hand.draw")
                            Text("Long press to draw")
                                .font(.caption)
                        }
                        .foregroundStyle(.purple)
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.5)))
                    }
                    .padding()
                }
            }

            if isSaving {
                Color.black.opacity(0.5).ignoresSafeArea()
                ProgressView("Saving...")
                    .tint(.white)
                    .foregroundStyle(.white)
            }

            if isDetecting {
                Color.black.opacity(0.5).ignoresSafeArea()
                ProgressView("Detecting...")
                    .tint(.white)
                    .foregroundStyle(.white)
            }
        }
        .navigationBarHidden(true)
        .alert("Delete File?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) { deleteFile() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
        .alert("Error", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
        .task {
            await loadPDF()
            await loadDetections()
            // Auto-detect on first view if no existing detections
            if detections.isEmpty && manualRedactions.isEmpty && pdfDocument != nil {
                runDetection()
            }
        }
    }

    // MARK: - Bindings for page-specific data

    private func detectionsBinding(for pageIndex: Int) -> Binding<[Detection]> {
        Binding(
            get: { detections.filter { $0.pageNumber == pageIndex + 1 } },
            set: { newValue in
                for updated in newValue {
                    if let index = detections.firstIndex(where: { $0.id == updated.id }) {
                        if detections[index].boundingBox != updated.boundingBox {
                            modifiedDetectionIds.insert(updated.id)
                        }
                        detections[index] = updated
                    }
                }
            }
        )
    }

    private func redactionsBinding(for pageIndex: Int) -> Binding<[ManualRedaction]> {
        Binding(
            get: { manualRedactions.filter { $0.pageNumber == pageIndex + 1 } },
            set: { newValue in
                for updated in newValue {
                    if let index = manualRedactions.firstIndex(where: { $0.id == updated.id }) {
                        if manualRedactions[index].boundingBox != updated.boundingBox {
                            modifiedRedactionIds.insert(updated.id)
                        }
                        manualRedactions[index] = updated
                    }
                }
            }
        )
    }

    // MARK: - Data Loading

    private func loadPDF() async {
        isLoading = true
        do {
            let data = try await APIService.shared.getFileOriginal(file.id)
            if let document = PDFDocument(data: data) {
                pdfDocument = document
                // Render all pages as images
                var images: [UIImage] = []
                for i in 0..<document.pageCount {
                    if let page = document.page(at: i) {
                        let image = renderPage(page)
                        images.append(image)
                    }
                }
                pageImages = images
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func renderPage(_ page: PDFPage) -> UIImage {
        let bounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)

        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else {
            return UIImage()
        }

        // Fill white background
        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        // Flip the context to correct PDF orientation
        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: scale, y: -scale)

        page.draw(with: .mediaBox, to: context)

        let image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        return image
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

    // MARK: - Actions

    private func addManualRedaction(bounds: CGRect, page: Int) {
        let id = "new-\(UUID().uuidString)"
        let redaction = ManualRedaction(
            id: id,
            fileId: file.id,
            redactionType: "manual",
            bboxX: bounds.origin.x,
            bboxY: bounds.origin.y,
            bboxWidth: bounds.width,
            bboxHeight: bounds.height,
            pageNumber: page,
            createdBy: "",
            createdAt: Int(Date().timeIntervalSince1970)
        )
        manualRedactions.append(redaction)
        newRedactionIds.insert(id)
    }

    private func deleteManualRedaction(id: String) {
        manualRedactions.removeAll { $0.id == id }
        if newRedactionIds.contains(id) {
            newRedactionIds.remove(id)
        } else {
            deletedRedactionIds.insert(id)
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
                        bboxX: region.boundingBox.origin.x,
                        bboxY: region.boundingBox.origin.y,
                        bboxWidth: region.boundingBox.width,
                        bboxHeight: region.boundingBox.height,
                        pageNumber: region.pageNumber,
                        textStart: nil,
                        textEnd: nil,
                        textContent: nil,
                        confidence: Double(region.confidence)
                    )
                }

                if !newDetections.isEmpty {
                    let created = try await APIService.shared.createDetections(
                        fileId: file.id,
                        detections: newDetections
                    )
                    await MainActor.run {
                        detections = created
                    }
                }

                await MainActor.run {
                    isDetecting = false
                }
            } catch {
                await MainActor.run {
                    isDetecting = false
                    self.error = error.localizedDescription
                }
            }
        }
    }

    private func saveChanges() {
        isSaving = true
        Task {
            do {
                // Create new redactions
                for id in newRedactionIds {
                    if let redaction = manualRedactions.first(where: { $0.id == id }),
                       let box = redaction.boundingBox {
                        let body = CreateManualRedactionBody(
                            redactionType: redaction.redactionType,
                            bboxX: box.origin.x,
                            bboxY: box.origin.y,
                            bboxWidth: box.width,
                            bboxHeight: box.height,
                            pageNumber: redaction.pageNumber
                        )
                        let created = try await APIService.shared.createManualRedaction(
                            fileId: file.id,
                            body: body
                        )
                        if let index = manualRedactions.firstIndex(where: { $0.id == id }) {
                            manualRedactions[index] = created
                        }
                    }
                }

                // Delete removed redactions
                for id in deletedRedactionIds {
                    try await APIService.shared.deleteManualRedaction(id)
                }

                // Update moved detections
                for id in modifiedDetectionIds {
                    if let detection = detections.first(where: { $0.id == id }),
                       let box = detection.boundingBox {
                        _ = try await APIService.shared.updateDetectionBounds(
                            id,
                            bboxX: box.origin.x,
                            bboxY: box.origin.y,
                            bboxWidth: box.width,
                            bboxHeight: box.height
                        )
                    }
                }

                // Update moved redactions
                for id in modifiedRedactionIds where !newRedactionIds.contains(id) {
                    if let redaction = manualRedactions.first(where: { $0.id == id }),
                       let box = redaction.boundingBox {
                        _ = try await APIService.shared.updateManualRedactionBounds(
                            id,
                            bboxX: box.origin.x,
                            bboxY: box.origin.y,
                            bboxWidth: box.width,
                            bboxHeight: box.height
                        )
                    }
                }

                // Clear tracking
                newRedactionIds.removeAll()
                deletedRedactionIds.removeAll()
                modifiedDetectionIds.removeAll()
                modifiedRedactionIds.removeAll()

                isSaving = false
            } catch {
                isSaving = false
                self.error = error.localizedDescription
            }
        }
    }

    private func deleteFile() {
        isDeleting = true
        Task {
            do {
                try await APIService.shared.deleteFile(file.id)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    self.error = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Page Editor View (single page with overlay)

struct PageEditorView: View {
    let image: UIImage
    @Binding var detections: [Detection]
    @Binding var manualRedactions: [ManualRedaction]
    @Binding var selectedDetectionId: String?
    let onRedactionCreated: (CGRect) -> Void
    let onRedactionDeleted: (String) -> Void

    var body: some View {
        GeometryReader { geometry in
            let imageSize = image.size
            let scale = min(
                geometry.size.width / imageSize.width,
                geometry.size.height / imageSize.height
            )
            let scaledSize = CGSize(
                width: imageSize.width * scale,
                height: imageSize.height * scale
            )

            ZStack {
                // Page image
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)

                // Detection/redaction overlay
                SimpleDetectionOverlay(
                    detections: $detections,
                    manualRedactions: $manualRedactions,
                    selectedDetectionId: $selectedDetectionId,
                    isDrawingMode: true,
                    onManualRedactionCreated: onRedactionCreated,
                    onManualRedactionDeleted: onRedactionDeleted
                )
                .frame(width: scaledSize.width, height: scaledSize.height)
            }
            .frame(width: scaledSize.width, height: scaledSize.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
