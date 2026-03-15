import SwiftUI

// MARK: - Simple Draggable Rectangle

struct DraggableRect: View {
    let id: String
    let normalizedBounds: CGRect
    let containerSize: CGSize
    let strokeColor: Color
    let fillColor: Color
    let isSelected: Bool
    let onSelect: () -> Void
    let onMove: (CGRect) -> Void  // Returns new normalized bounds

    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false

    // Convert normalized (0-1, bottom-left origin) to view coordinates (top-left origin)
    private var viewBounds: CGRect {
        CGRect(
            x: normalizedBounds.origin.x * containerSize.width,
            y: (1 - normalizedBounds.origin.y - normalizedBounds.height) * containerSize.height,
            width: normalizedBounds.width * containerSize.width,
            height: normalizedBounds.height * containerSize.height
        )
    }

    private var currentPosition: CGPoint {
        CGPoint(
            x: viewBounds.midX + dragOffset.width,
            y: viewBounds.midY + dragOffset.height
        )
    }

    var body: some View {
        Rectangle()
            .stroke(strokeColor, lineWidth: isSelected ? 4 : 2)
            .background(fillColor.opacity(isDragging ? 0.5 : 0.3))
            .frame(width: viewBounds.width, height: viewBounds.height)
            .position(currentPosition)
            .gesture(
                DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        isDragging = true
                        dragOffset = value.translation
                    }
                    .onEnded { value in
                        isDragging = false

                        // Calculate new view bounds
                        let newViewBounds = CGRect(
                            x: viewBounds.origin.x + value.translation.width,
                            y: viewBounds.origin.y + value.translation.height,
                            width: viewBounds.width,
                            height: viewBounds.height
                        )

                        // Convert back to normalized coordinates
                        let newNormalized = CGRect(
                            x: newViewBounds.origin.x / containerSize.width,
                            y: 1 - (newViewBounds.origin.y + newViewBounds.height) / containerSize.height,
                            width: newViewBounds.width / containerSize.width,
                            height: newViewBounds.height / containerSize.height
                        )

                        dragOffset = .zero
                        onMove(newNormalized)
                    }
            )
            .onTapGesture {
                onSelect()
            }
    }
}

// MARK: - Simple Detection Overlay

struct SimpleDetectionOverlay: View {
    @Binding var detections: [Detection]
    @Binding var manualRedactions: [ManualRedaction]
    @Binding var selectedDetectionId: String?
    let isDrawingMode: Bool
    let onManualRedactionCreated: (CGRect) -> Void
    let onManualRedactionDeleted: (String) -> Void

    @State private var drawStart: CGPoint?
    @State private var drawCurrent: CGPoint?
    @State private var isDrawing = false
    @State private var redactionToDelete: ManualRedaction?

    private func drawingGesture(in size: CGSize) -> some Gesture {
        LongPressGesture(minimumDuration: 0.3)
            .sequenced(before: DragGesture(minimumDistance: 1))
            .onChanged { value in
                switch value {
                case .first(true):
                    break
                case .second(true, let drag):
                    if let drag = drag {
                        if drawStart == nil {
                            drawStart = drag.startLocation
                        }
                        drawCurrent = drag.location
                        isDrawing = true
                    }
                default:
                    break
                }
            }
            .onEnded { value in
                if case .second(true, let drag) = value, let drag = drag, let start = drawStart {
                    let current = drag.location
                    let minX = min(start.x, current.x)
                    let minY = min(start.y, current.y)
                    let width = abs(current.x - start.x)
                    let height = abs(current.y - start.y)

                    if width > 20 && height > 20 {
                        let normalized = CGRect(
                            x: minX / size.width,
                            y: 1 - (minY + height) / size.height,
                            width: width / size.width,
                            height: height / size.height
                        )
                        onManualRedactionCreated(normalized)
                    }
                }

                drawStart = nil
                drawCurrent = nil
                isDrawing = false
            }
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Drawing preview
                if isDrawing, let start = drawStart, let current = drawCurrent {
                    let rect = CGRect(
                        x: min(start.x, current.x),
                        y: min(start.y, current.y),
                        width: abs(current.x - start.x),
                        height: abs(current.y - start.y)
                    )
                    Rectangle()
                        .stroke(Color.purple, lineWidth: 2)
                        .background(Color.purple.opacity(0.3))
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .allowsHitTesting(false)
                }

                // Manual redaction rectangles
                ForEach(manualRedactions) { redaction in
                    if let bounds = redaction.boundingBox {
                        DraggableRect(
                            id: redaction.id,
                            normalizedBounds: bounds,
                            containerSize: geometry.size,
                            strokeColor: .purple,
                            fillColor: .purple,
                            isSelected: false,
                            onSelect: {
                                redactionToDelete = redaction
                            },
                            onMove: { newBounds in
                                updateManualRedaction(redaction, newBounds: newBounds)
                            }
                        )
                    }
                }

                // Detection rectangles
                ForEach(detections) { detection in
                    if let bounds = detection.boundingBox {
                        DraggableRect(
                            id: detection.id,
                            normalizedBounds: bounds,
                            containerSize: geometry.size,
                            strokeColor: strokeColor(for: detection.status),
                            fillColor: fillColor(for: detection.status),
                            isSelected: selectedDetectionId == detection.id,
                            onSelect: {
                                selectedDetectionId = detection.id
                            },
                            onMove: { newBounds in
                                updateDetection(detection, newBounds: newBounds)
                            }
                        )
                    }
                }
            }
            .confirmationDialog(
                "Delete Redaction",
                isPresented: Binding(
                    get: { redactionToDelete != nil },
                    set: { if !$0 { redactionToDelete = nil } }
                ),
                presenting: redactionToDelete
            ) { redaction in
                Button("Delete", role: .destructive) {
                    onManualRedactionDeleted(redaction.id)
                    redactionToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    redactionToDelete = nil
                }
            } message: { _ in
                Text("Are you sure you want to delete this redaction?")
            }
            .contentShape(Rectangle())
            .simultaneousGesture(isDrawingMode ? drawingGesture(in: geometry.size) : nil)
        }
    }

    private func updateDetection(_ detection: Detection, newBounds: CGRect) {
        if let index = detections.firstIndex(where: { $0.id == detection.id }) {
            let old = detections[index]
            detections[index] = Detection(
                id: old.id,
                fileId: old.fileId,
                detectionType: old.detectionType,
                bboxX: newBounds.origin.x,
                bboxY: newBounds.origin.y,
                bboxWidth: newBounds.width,
                bboxHeight: newBounds.height,
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
    }

    private func updateManualRedaction(_ redaction: ManualRedaction, newBounds: CGRect) {
        if let index = manualRedactions.firstIndex(where: { $0.id == redaction.id }) {
            let old = manualRedactions[index]
            manualRedactions[index] = ManualRedaction(
                id: old.id,
                fileId: old.fileId,
                redactionType: old.redactionType,
                bboxX: newBounds.origin.x,
                bboxY: newBounds.origin.y,
                bboxWidth: newBounds.width,
                bboxHeight: newBounds.height,
                pageNumber: old.pageNumber,
                createdBy: old.createdBy,
                createdAt: old.createdAt
            )
        }
    }

    private func strokeColor(for status: DetectionStatus) -> Color {
        .orange
    }

    private func fillColor(for status: DetectionStatus) -> Color {
        .orange
    }
}

// MARK: - Legacy API Compatibility (for existing views that use DetectionOverlayView)

struct DetectionOverlayView: View {
    let detections: [Detection]
    let manualRedactions: [ManualRedaction]
    let isDrawingMode: Bool
    @Binding var drawingRect: CGRect?
    var onDrawComplete: ((CGRect) -> Void)?
    var onDetectionMoved: ((Detection, CGRect) -> Void)?
    var onManualRedactionMoved: ((ManualRedaction, CGRect) -> Void)?
    var onManualRedactionDelete: ((ManualRedaction) -> Void)?
    @Binding var selectedDetectionId: String?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Detection rectangles (display only)
                ForEach(detections) { detection in
                    if let bounds = detection.boundingBox {
                        let viewBounds = convertToView(bounds, in: geometry.size)
                        Rectangle()
                            .stroke(strokeColor(for: detection.status), lineWidth: selectedDetectionId == detection.id ? 4 : 2)
                            .background(fillColor(for: detection.status).opacity(0.3))
                            .frame(width: viewBounds.width, height: viewBounds.height)
                            .position(x: viewBounds.midX, y: viewBounds.midY)
                    }
                }

                // Manual redaction rectangles (display only)
                ForEach(manualRedactions) { redaction in
                    if let bounds = redaction.boundingBox {
                        let viewBounds = convertToView(bounds, in: geometry.size)
                        Rectangle()
                            .stroke(Color.purple, lineWidth: 2)
                            .background(Color.purple.opacity(0.3))
                            .frame(width: viewBounds.width, height: viewBounds.height)
                            .position(x: viewBounds.midX, y: viewBounds.midY)
                    }
                }
            }
        }
    }

    private func convertToView(_ normalized: CGRect, in size: CGSize) -> CGRect {
        CGRect(
            x: normalized.origin.x * size.width,
            y: (1 - normalized.origin.y - normalized.height) * size.height,
            width: normalized.width * size.width,
            height: normalized.height * size.height
        )
    }

    private func strokeColor(for status: DetectionStatus) -> Color {
        .orange
    }

    private func fillColor(for status: DetectionStatus) -> Color {
        .orange
    }
}

#Preview {
    SimpleDetectionOverlay(
        detections: .constant([]),
        manualRedactions: .constant([]),
        selectedDetectionId: .constant(nil),
        isDrawingMode: true,
        onManualRedactionCreated: { _ in },
        onManualRedactionDeleted: { _ in }
    )
}
