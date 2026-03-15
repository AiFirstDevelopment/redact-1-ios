import SwiftUI

struct ImageReviewView: View {
    let file: EvidenceFile

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var detections: [Detection] = []
    @State private var manualRedactions: [ManualRedaction] = []
    @State private var isLoading = false
    @State private var isDetecting = false
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var showingDeleteConfirmation = false
    @State private var error: String?
    @State private var showingPreview = false
    @State private var isDrawingMode = false
    @State private var drawingRect: CGRect?
    @State private var selectedDetectionId: String?
    @State private var detectionMessage: String?
    @State private var isFullscreen = false

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Drawing mode hint
                if isDrawingMode {
                    HStack {
                        Image(systemName: "hand.draw")
                        Text("Drag on the image to draw a redaction box")
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
                        Image(systemName: detections.isEmpty ? "info.circle" : "checkmark.circle.fill")
                        Text(message)
                            .font(.subheadline)
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity)
                    .background(detections.isEmpty ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
                    .foregroundStyle(detections.isEmpty ? .orange : .green)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut, value: detectionMessage)
                }

                // Image with overlays
                ZStack {
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .overlay {
                                DetectionOverlayView(
                                    detections: detections,
                                    manualRedactions: manualRedactions,
                                    isDrawingMode: isDrawingMode,
                                    drawingRect: $drawingRect,
                                    onDrawComplete: handleDrawComplete,
                                    onDetectionMoved: handleDetectionMoved,
                                    selectedDetectionId: $selectedDetectionId
                                )
                            }
                            .onTapGesture {
                                // Enter fullscreen for easier editing
                                isFullscreen = true
                            }
                            .border(isDrawingMode ? Color.purple : Color.clear, width: 3)
                    } else if isLoading {
                        ProgressView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Detection list
                if !detections.isEmpty || !manualRedactions.isEmpty {
                    List {
                        Section("Detections") {
                            ForEach(detections) { detection in
                                DetectionRow(detection: detection) { newStatus in
                                    Task {
                                        await updateDetection(detection, status: newStatus)
                                    }
                                }
                            }
                        }

                        if !manualRedactions.isEmpty {
                            Section("Manual Redactions") {
                                ForEach(manualRedactions) { redaction in
                                    HStack {
                                        Image(systemName: "rectangle.inset.filled")
                                        Text(redaction.redactionType)
                                        Spacer()
                                    }
                                }
                                .onDelete(perform: deleteManualRedactions)
                            }
                        }
                    }
                    .frame(height: geometry.size.height * 0.35)
                }
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
                .disabled(image == nil || isDetecting)

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
            if let image = image {
                RedactionPreviewView(
                    originalImage: image,
                    detections: detections,
                    manualRedactions: manualRedactions
                )
            }
        }
        .fullScreenCover(isPresented: $isFullscreen) {
            if let image = image {
                FullscreenImageEditor(
                    image: image,
                    detections: $detections,
                    manualRedactions: $manualRedactions,
                    fileId: file.id
                )
            }
        }
        .alert("Error", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
        .task {
            await loadImage()
            await loadDetections()
        }
    }

    private func loadImage() async {
        isLoading = true
        do {
            let data = try await APIService.shared.getFileOriginal(file.id)
            if let uiImage = UIImage(data: data) {
                image = uiImage
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
        guard let image = image else { return }

        isDetecting = true
        Task {
            do {
                // Clear existing detections first
                try await APIService.shared.clearDetections(fileId: file.id)
                await MainActor.run { detections = [] }

                let regions = try await VisionService.shared.detectInImage(image)

                let newDetections = regions.map { region in
                    CreateDetectionBody(
                        detectionType: region.type.rawValue,
                        bboxX: Double(region.boundingBox.origin.x),
                        bboxY: Double(region.boundingBox.origin.y),
                        bboxWidth: Double(region.boundingBox.width),
                        bboxHeight: Double(region.boundingBox.height),
                        pageNumber: nil,
                        textStart: nil,
                        textEnd: nil,
                        textContent: region.textContent,
                        confidence: Double(region.confidence)
                    )
                }

                await MainActor.run {
                    if !newDetections.isEmpty {
                        // Show success message
                        let faceCount = newDetections.filter { $0.detectionType == "face" }.count
                        let otherCount = newDetections.count - faceCount
                        var parts: [String] = []
                        if faceCount > 0 { parts.append("\(faceCount) face\(faceCount > 1 ? "s" : "")") }
                        if otherCount > 0 { parts.append("\(otherCount) other") }
                        detectionMessage = "Found \(parts.joined(separator: ", "))"
                    } else {
                        detectionMessage = "No sensitive content detected"
                    }
                }

                if !newDetections.isEmpty {
                    let savedDetections = try await APIService.shared.createDetections(
                        fileId: file.id,
                        detections: newDetections
                    )
                    await MainActor.run {
                        detections = savedDetections
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

    private func handleDrawComplete(_ rect: CGRect) {
        Task {
            do {
                let body = CreateManualRedactionBody(
                    redactionType: "manual",
                    bboxX: Double(rect.origin.x),
                    bboxY: Double(rect.origin.y),
                    bboxWidth: Double(rect.width),
                    bboxHeight: Double(rect.height),
                    pageNumber: nil
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
        drawingRect = nil
        isDrawingMode = false
    }

    private func handleDetectionMoved(_ detection: Detection, _ newRect: CGRect) {
        // Optimistically update local state to prevent snap-back
        if let index = detections.firstIndex(where: { $0.id == detection.id }) {
            let old = detections[index]
            detections[index] = Detection(
                id: old.id,
                fileId: old.fileId,
                detectionType: old.detectionType,
                bboxX: Double(newRect.origin.x),
                bboxY: Double(newRect.origin.y),
                bboxWidth: Double(newRect.width),
                bboxHeight: Double(newRect.height),
                pageNumber: old.pageNumber,
                textStart: old.textStart,
                textEnd: old.textEnd,
                textContent: old.textContent,
                confidence: old.confidence,
                status: old.status,
                reviewedBy: old.reviewedBy,
                reviewedAt: old.reviewedAt,
                createdAt: old.createdAt
            )
        }

        Task {
            do {
                _ = try await APIService.shared.updateDetectionBounds(
                    detection.id,
                    bboxX: Double(newRect.origin.x),
                    bboxY: Double(newRect.origin.y),
                    bboxWidth: Double(newRect.width),
                    bboxHeight: Double(newRect.height)
                )
            } catch {
                self.error = error.localizedDescription
            }
        }
        selectedDetectionId = nil
    }

    private func deleteManualRedactions(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let redaction = manualRedactions[index]
                do {
                    try await APIService.shared.deleteManualRedaction(redaction.id)
                    manualRedactions.remove(at: index)
                } catch {
                    self.error = error.localizedDescription
                }
            }
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

    private func saveReview() {
        guard let image = image else { return }

        isSaving = true
        Task {
            do {
                // Apply redactions
                guard let redactedImage = RedactionService.shared.applyRedactions(
                    to: image,
                    detections: detections,
                    manualRedactions: manualRedactions
                ) else {
                    throw RedactionError.failed
                }

                // Upload redacted image
                guard let imageData = RedactionService.shared.exportImage(redactedImage) else {
                    throw RedactionError.exportFailed
                }

                try await APIService.shared.uploadRedactedFile(
                    file.id,
                    data: imageData,
                    mimeType: "image/jpeg"
                )
            } catch {
                self.error = error.localizedDescription
            }
            isSaving = false
        }
    }
}

enum RedactionError: Error, LocalizedError {
    case failed
    case exportFailed

    var errorDescription: String? {
        switch self {
        case .failed: return "Failed to apply redactions"
        case .exportFailed: return "Failed to export redacted file"
        }
    }
}

struct DetectionRow: View {
    let detection: Detection
    var onStatusChange: ((DetectionStatus) -> Void)?

    var body: some View {
        HStack {
            Image(systemName: detection.detectionType.iconName)
                .foregroundStyle(statusColor)

            VStack(alignment: .leading) {
                Text(detection.detectionType.displayName)
                    .font(.headline)
                if let text = detection.textContent {
                    Text(text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 12) {
                Button(action: { onStatusChange?(.approved) }) {
                    Image(systemName: detection.status == .approved ? "checkmark.circle.fill" : "checkmark.circle")
                        .foregroundStyle(detection.status == .approved ? .green : .gray)
                }

                Button(action: { onStatusChange?(.rejected) }) {
                    Image(systemName: detection.status == .rejected ? "xmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(detection.status == .rejected ? .red : .gray)
                }
            }
            .buttonStyle(.plain)
        }
    }

    var statusColor: Color {
        switch detection.status {
        case .pending: return .orange
        case .approved: return .green
        case .rejected: return .red
        }
    }
}

struct FullscreenImageEditor: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    @Binding var detections: [Detection]
    @Binding var manualRedactions: [ManualRedaction]
    let fileId: String

    @State private var drawingRect: CGRect?
    @State private var selectedDetectionId: String?
    @State private var error: String?

    // Track original state for cancel
    @State private var originalDetections: [Detection] = []
    @State private var originalManualRedactions: [ManualRedaction] = []

    // Track pending changes to sync on Done
    @State private var pendingNewRedactions: [ManualRedaction] = []
    @State private var pendingDeletedRedactionIds: [String] = []
    @State private var movedDetectionIds: Set<String> = []
    @State private var movedRedactionIds: Set<String> = []

    @State private var isSaving = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Zoomable image with overlay - always in drawing mode
            ZoomableImageView(image: image) {
                DetectionOverlayView(
                    detections: detections,
                    manualRedactions: manualRedactions,
                    isDrawingMode: true,
                    drawingRect: $drawingRect,
                    onDrawComplete: handleDrawComplete,
                    onDetectionMoved: handleDetectionMoved,
                    onManualRedactionMoved: handleManualRedactionMoved,
                    onManualRedactionDelete: handleManualRedactionDelete,
                    selectedDetectionId: $selectedDetectionId
                )
            }
            .onTapGesture {
                selectedDetectionId = nil
            }

            // Top controls
            VStack {
                HStack {
                    Button("Cancel") {
                        // Just restore original state - no API calls
                        detections = originalDetections
                        manualRedactions = originalManualRedactions
                        dismiss()
                    }
                    .foregroundStyle(.white)
                    .padding()
                    .disabled(isSaving)

                    Spacer()

                    Button("Done") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding()
                    .disabled(isSaving)
                }
                .background(Color.black.opacity(0.5))

                Text("Hold to draw • Tap box to move")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(Color.purple.opacity(0.8))
                    .cornerRadius(8)

                Spacer()
            }

            if isSaving {
                Color.black.opacity(0.5).ignoresSafeArea()
                ProgressView("Saving...")
                    .tint(.white)
                    .foregroundStyle(.white)
            }
        }
        .statusBar(hidden: true)
        .onAppear {
            // Save original state for cancel
            originalDetections = detections
            originalManualRedactions = manualRedactions
        }
        .alert("Error", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
    }

    private func saveChanges() {
        isSaving = true
        Task {
            do {
                // Create new redactions
                for pending in pendingNewRedactions {
                    let body = CreateManualRedactionBody(
                        redactionType: pending.redactionType,
                        bboxX: pending.bboxX ?? 0,
                        bboxY: pending.bboxY ?? 0,
                        bboxWidth: pending.bboxWidth ?? 0,
                        bboxHeight: pending.bboxHeight ?? 0,
                        pageNumber: pending.pageNumber
                    )
                    let created = try await APIService.shared.createManualRedaction(
                        fileId: fileId,
                        body: body
                    )
                    // Replace temp ID with real ID
                    if let index = manualRedactions.firstIndex(where: { $0.id == pending.id }) {
                        manualRedactions[index] = created
                    }
                }

                // Delete removed redactions (only non-temp ones that existed before)
                for redactionId in pendingDeletedRedactionIds {
                    if !redactionId.hasPrefix("temp-") {
                        try await APIService.shared.deleteManualRedaction(redactionId)
                    }
                }

                // Update moved detections
                for detectionId in movedDetectionIds {
                    if let detection = detections.first(where: { $0.id == detectionId }),
                       let box = detection.boundingBox {
                        _ = try await APIService.shared.updateDetectionBounds(
                            detectionId,
                            bboxX: box.origin.x,
                            bboxY: box.origin.y,
                            bboxWidth: box.width,
                            bboxHeight: box.height
                        )
                    }
                }

                // Update moved redactions (only non-temp ones)
                for redactionId in movedRedactionIds {
                    if !redactionId.hasPrefix("temp-"),
                       let redaction = manualRedactions.first(where: { $0.id == redactionId }),
                       let box = redaction.boundingBox {
                        _ = try await APIService.shared.updateManualRedactionBounds(
                            redactionId,
                            bboxX: box.origin.x,
                            bboxY: box.origin.y,
                            bboxWidth: box.width,
                            bboxHeight: box.height
                        )
                    }
                }

                isSaving = false
                dismiss()
            } catch {
                isSaving = false
                self.error = error.localizedDescription
            }
        }
    }

    private func handleDrawComplete(_ rect: CGRect) {
        // Create local redaction with temporary ID
        let tempId = "temp-\(UUID().uuidString)"
        let newRedaction = ManualRedaction(
            id: tempId,
            fileId: fileId,
            redactionType: "manual",
            bboxX: Double(rect.origin.x),
            bboxY: Double(rect.origin.y),
            bboxWidth: Double(rect.width),
            bboxHeight: Double(rect.height),
            pageNumber: nil,
            createdBy: "",
            createdAt: Int(Date().timeIntervalSince1970)
        )
        manualRedactions.append(newRedaction)
        pendingNewRedactions.append(newRedaction)
        drawingRect = nil
    }

    private func handleDetectionMoved(_ detection: Detection, _ newRect: CGRect) {
        // Update local state only
        if let index = detections.firstIndex(where: { $0.id == detection.id }) {
            let old = detections[index]
            detections[index] = Detection(
                id: old.id,
                fileId: old.fileId,
                detectionType: old.detectionType,
                bboxX: Double(newRect.origin.x),
                bboxY: Double(newRect.origin.y),
                bboxWidth: Double(newRect.width),
                bboxHeight: Double(newRect.height),
                pageNumber: old.pageNumber,
                textStart: old.textStart,
                textEnd: old.textEnd,
                textContent: old.textContent,
                confidence: old.confidence,
                status: old.status,
                reviewedBy: old.reviewedBy,
                reviewedAt: old.reviewedAt,
                createdAt: old.createdAt
            )
            movedDetectionIds.insert(detection.id)
        }
        selectedDetectionId = nil
    }

    private func handleManualRedactionMoved(_ redaction: ManualRedaction, _ newRect: CGRect) {
        // Update local state only
        if let index = manualRedactions.firstIndex(where: { $0.id == redaction.id }) {
            let old = manualRedactions[index]
            manualRedactions[index] = ManualRedaction(
                id: old.id,
                fileId: old.fileId,
                redactionType: old.redactionType,
                bboxX: Double(newRect.origin.x),
                bboxY: Double(newRect.origin.y),
                bboxWidth: Double(newRect.width),
                bboxHeight: Double(newRect.height),
                pageNumber: old.pageNumber,
                createdBy: old.createdBy,
                createdAt: old.createdAt
            )
            movedRedactionIds.insert(redaction.id)
        }
    }

    private func handleManualRedactionDelete(_ redaction: ManualRedaction) {
        // Remove locally and track for deletion on save
        manualRedactions.removeAll { $0.id == redaction.id }
        pendingNewRedactions.removeAll { $0.id == redaction.id }
        if !redaction.id.hasPrefix("temp-") {
            pendingDeletedRedactionIds.append(redaction.id)
        }
    }
}

struct ZoomableImageView<Overlay: View>: View {
    let image: UIImage
    let overlay: () -> Overlay

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .overlay { overlay() }
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            scale = lastScale * value
                        }
                        .onEnded { _ in
                            lastScale = scale
                            if scale < 1 {
                                withAnimation { scale = 1; lastScale = 1 }
                            }
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation {
                        if scale > 1 {
                            scale = 1
                            lastScale = 1
                            offset = .zero
                            lastOffset = .zero
                        } else {
                            scale = 2
                            lastScale = 2
                        }
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

#Preview {
    NavigationStack {
        ImageReviewView(file: EvidenceFile(
            id: "test",
            requestId: "req",
            filename: "test.jpg",
            fileType: .image,
            mimeType: "image/jpeg",
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
