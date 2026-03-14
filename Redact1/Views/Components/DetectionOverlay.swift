import SwiftUI

struct DetectionOverlayView: View {
    let detections: [Detection]
    let manualRedactions: [ManualRedaction]
    let isDrawingMode: Bool
    @Binding var drawingRect: CGRect?
    var onDrawComplete: ((CGRect) -> Void)?

    @State private var dragStart: CGPoint?

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Detection boxes
                ForEach(detections) { detection in
                    if let bbox = detection.boundingBox {
                        let rect = convertToViewCoordinates(bbox, in: geometry.size)
                        Rectangle()
                            .stroke(strokeColor(for: detection.status), lineWidth: 2)
                            .background(fillColor(for: detection.status).opacity(0.2))
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                    }
                }

                // Manual redaction boxes
                ForEach(manualRedactions) { redaction in
                    if let bbox = redaction.boundingBox {
                        let rect = convertToViewCoordinates(bbox, in: geometry.size)
                        Rectangle()
                            .stroke(Color.purple, lineWidth: 2)
                            .background(Color.purple.opacity(0.2))
                            .frame(width: rect.width, height: rect.height)
                            .position(x: rect.midX, y: rect.midY)
                    }
                }

                // Drawing overlay
                if isDrawingMode {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
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

#Preview {
    DetectionOverlayView(
        detections: [],
        manualRedactions: [],
        isDrawingMode: true,
        drawingRect: .constant(nil)
    )
}
