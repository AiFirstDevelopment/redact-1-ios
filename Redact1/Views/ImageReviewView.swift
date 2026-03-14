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
                                    onDrawComplete: handleDrawComplete
                                )
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
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 16) {
                    Button(action: { isDrawingMode.toggle() }) {
                        Image(systemName: isDrawingMode ? "pencil.circle.fill" : "pencil.circle")
                    }
                    .disabled(image == nil)

                    Button(action: runDetection) {
                        if isDetecting {
                            ProgressView()
                        } else {
                            Image(systemName: "wand.and.stars")
                        }
                    }
                    .disabled(image == nil || isDetecting)

                    Button(action: { showingPreview = true }) {
                        Image(systemName: "eye")
                    }
                    .disabled(image == nil)

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
            createdAt: 0,
            updatedAt: 0
        ))
    }
}
