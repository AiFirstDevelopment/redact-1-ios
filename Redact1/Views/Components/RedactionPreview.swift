import SwiftUI

struct RedactionPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let originalImage: UIImage
    let detections: [Detection]
    let manualRedactions: [ManualRedaction]

    @State private var showingOriginal = false

    var redactedImage: UIImage? {
        RedactionService.shared.applyRedactions(
            to: originalImage,
            detections: detections,
            manualRedactions: manualRedactions
        )
    }

    var body: some View {
        NavigationStack {
            VStack {
                if showingOriginal {
                    Image(uiImage: originalImage)
                        .resizable()
                        .scaledToFit()
                } else if let redacted = redactedImage {
                    Image(uiImage: redacted)
                        .resizable()
                        .scaledToFit()
                }

                Spacer()

                HStack {
                    Button(action: { showingOriginal = true }) {
                        VStack {
                            Image(systemName: "photo")
                            Text("Original")
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(showingOriginal ? .blue : .gray)

                    Spacer()

                    Button(action: { showingOriginal = false }) {
                        VStack {
                            Image(systemName: "rectangle.inset.filled")
                            Text("Redacted")
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(!showingOriginal ? .blue : .gray)
                }
                .padding()
            }
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    RedactionPreviewView(
        originalImage: UIImage(systemName: "photo")!,
        detections: [],
        manualRedactions: []
    )
}
