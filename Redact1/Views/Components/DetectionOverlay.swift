import SwiftUI

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

    @State private var dragStart: CGPoint?
    @State private var dragOffsets: [String: CGSize] = [:]
    @State private var resizeOffsets: [String: CGSize] = [:]
    @State private var activeResizeCorner: ResizeCorner?

    enum ResizeCorner {
        case topLeft, topRight, bottomLeft, bottomRight
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Drawing overlay (FIRST so it's behind detection boxes)
                if isDrawingMode {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 1)
                                .onChanged { value in
                                    if dragStart == nil {
                                        dragStart = value.startLocation
                                    }
                                    guard let start = dragStart else { return }
                                    let current = value.location

                                    let minX = min(start.x, current.x)
                                    let minY = min(start.y, current.y)
                                    let width = abs(current.x - start.x)
                                    let height = abs(current.y - start.y)

                                    drawingRect = CGRect(x: minX, y: minY, width: width, height: height)
                                }
                                .onEnded { value in
                                    if let rect = drawingRect, rect.width > 10 && rect.height > 10 {
                                        // Convert to normalized coordinates
                                        let normalizedRect = CGRect(
                                            x: rect.origin.x / geometry.size.width,
                                            y: 1 - (rect.origin.y + rect.height) / geometry.size.height,
                                            width: rect.width / geometry.size.width,
                                            height: rect.height / geometry.size.height
                                        )
                                        onDrawComplete?(normalizedRect)
                                    }
                                    dragStart = nil
                                    drawingRect = nil
                                }
                        )

                    // Drawing rect preview
                    if let rect = drawingRect {
                        Rectangle()
                            .stroke(Color.purple, lineWidth: 2)
                            .background(Color.purple.opacity(0.3))
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                            .allowsHitTesting(false)
                    }
                }

                // Detection boxes (on top so they can be tapped)
                ForEach(Array(detections.enumerated()), id: \.element.id) { index, detection in
                    if let bbox = detection.boundingBox, bbox.width > 0, bbox.height > 0 {
                        let baseRect = convertToViewCoordinates(bbox, in: geometry.size)
                        let offset = dragOffsets[detection.id] ?? .zero
                        let resize = resizeOffsets[detection.id] ?? .zero
                        let rect = CGRect(
                            x: baseRect.origin.x + offset.width,
                            y: baseRect.origin.y + offset.height,
                            width: max(30, baseRect.width + resize.width),
                            height: max(30, baseRect.height + resize.height)
                        )

                        EditableDetectionBox(
                            rect: rect,
                            color: strokeColor(for: detection.status),
                            fillColor: fillColor(for: detection.status),
                            isSelected: selectedDetectionId == detection.id,
                            onTap: {
                                selectedDetectionId = detection.id
                            },
                            onDrag: { offset in
                                dragOffsets[detection.id] = offset
                            },
                            onDragEnd: {
                                if let offset = dragOffsets[detection.id], offset != .zero {
                                    let newRect = CGRect(
                                        x: rect.origin.x,
                                        y: rect.origin.y,
                                        width: rect.width,
                                        height: rect.height
                                    )
                                    let normalizedRect = convertToNormalizedCoordinates(newRect, in: geometry.size)
                                    onDetectionMoved?(detection, normalizedRect)
                                }
                                dragOffsets[detection.id] = .zero
                            },
                            onResize: { corner, delta in
                                resizeOffsets[detection.id] = delta
                            },
                            onResizeEnd: {
                                if let resize = resizeOffsets[detection.id], resize != .zero {
                                    let newRect = CGRect(
                                        x: rect.origin.x,
                                        y: rect.origin.y,
                                        width: rect.width,
                                        height: rect.height
                                    )
                                    let normalizedRect = convertToNormalizedCoordinates(newRect, in: geometry.size)
                                    onDetectionMoved?(detection, normalizedRect)
                                }
                                resizeOffsets[detection.id] = .zero
                            }
                        )
                        .zIndex(selectedDetectionId == detection.id ? 100 : Double(index))
                    }
                }

                // Manual redaction boxes
                ForEach(manualRedactions) { redaction in
                    if let bbox = redaction.boundingBox {
                        let baseRect = convertToViewCoordinates(bbox, in: geometry.size)
                        let offset = dragOffsets[redaction.id] ?? .zero
                        let rect = CGRect(
                            x: baseRect.origin.x + offset.width,
                            y: baseRect.origin.y + offset.height,
                            width: baseRect.width,
                            height: baseRect.height
                        )

                        Rectangle()
                            .stroke(Color.purple, lineWidth: 3)
                            .background(Color.purple.opacity(0.3))
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        dragOffsets[redaction.id] = CGSize(
                                            width: value.translation.width,
                                            height: value.translation.height
                                        )
                                    }
                                    .onEnded { _ in
                                        if let currentOffset = dragOffsets[redaction.id], currentOffset != .zero {
                                            let newRect = CGRect(
                                                x: rect.origin.x,
                                                y: rect.origin.y,
                                                width: rect.width,
                                                height: rect.height
                                            )
                                            let normalizedRect = convertToNormalizedCoordinates(newRect, in: geometry.size)
                                            onManualRedactionMoved?(redaction, normalizedRect)
                                        }
                                        dragOffsets[redaction.id] = .zero
                                    }
                            )
                            .contextMenu {
                                Button(role: .destructive) {
                                    onManualRedactionDelete?(redaction)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                }

            }
        }
    }

    private func convertToViewCoordinates(_ normalizedRect: CGRect, in size: CGSize) -> CGRect {
        // Vision uses bottom-left origin with normalized coordinates
        let x = normalizedRect.origin.x * size.width
        let y = (1 - normalizedRect.origin.y - normalizedRect.height) * size.height
        let width = normalizedRect.width * size.width
        let height = normalizedRect.height * size.height

        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func convertToNormalizedCoordinates(_ viewRect: CGRect, in size: CGSize) -> CGRect {
        let x = viewRect.origin.x / size.width
        let y = 1 - (viewRect.origin.y + viewRect.height) / size.height
        let width = viewRect.width / size.width
        let height = viewRect.height / size.height

        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func strokeColor(for status: DetectionStatus) -> Color {
        switch status {
        case .pending: return .orange
        case .approved: return .green
        case .rejected: return .red
        }
    }

    private func fillColor(for status: DetectionStatus) -> Color {
        switch status {
        case .pending: return .orange
        case .approved: return .green
        case .rejected: return .clear
        }
    }
}

struct EditableDetectionBox: View {
    let rect: CGRect
    let color: Color
    let fillColor: Color
    let isSelected: Bool
    var onTap: () -> Void
    var onDrag: (CGSize) -> Void
    var onDragEnd: () -> Void
    var onResize: (DetectionOverlayView.ResizeCorner, CGSize) -> Void
    var onResizeEnd: () -> Void

    private let handleSize: CGFloat = 24

    var body: some View {
        ZStack {
            // Main rectangle - use highPriorityGesture to win over drawing overlay
            Rectangle()
                .stroke(color, lineWidth: isSelected ? 4 : 3)
                .background(fillColor.opacity(0.3))
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .contentShape(Rectangle())
                .onTapGesture {
                    onTap()
                }
                .highPriorityGesture(
                    DragGesture(minimumDistance: 5)
                        .onChanged { value in
                            onDrag(value.translation)
                        }
                        .onEnded { _ in
                            onDragEnd()
                        }
                )

            // Resize handles (only show when selected)
            if isSelected {
                // Corner handle - bottom right
                Circle()
                    .fill(color)
                    .frame(width: handleSize, height: handleSize)
                    .position(x: rect.maxX, y: rect.maxY)
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                onResize(.bottomRight, value.translation)
                            }
                            .onEnded { _ in
                                onResizeEnd()
                            }
                    )
            }
        }
    }
}

#Preview {
    DetectionOverlayView(
        detections: [],
        manualRedactions: [],
        isDrawingMode: true,
        drawingRect: .constant(nil),
        selectedDetectionId: .constant(nil)
    )
}
