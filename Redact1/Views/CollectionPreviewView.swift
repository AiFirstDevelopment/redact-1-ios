import SwiftUI
import PDFKit

struct CollectionPreviewView: View {
    let files: [EvidenceFile]

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex = 0
    @State private var previewItems: [PreviewItem] = []
    @State private var isLoading = true
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if isLoading {
                    ProgressView("Loading previews...")
                        .tint(.white)
                        .foregroundStyle(.white)
                } else if previewItems.isEmpty {
                    ContentUnavailableView(
                        "No Previews",
                        systemImage: "doc",
                        description: Text("No redacted files to preview")
                    )
                } else {
                    TabView(selection: $currentIndex) {
                        ForEach(Array(previewItems.enumerated()), id: \.offset) { index, item in
                            PreviewPageView(item: item)
                                .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))

                    // Page indicator overlay
                    VStack {
                        HStack {
                            Spacer()

                            HStack(spacing: 12) {
                                Button(action: { withAnimation { currentIndex -= 1 } }) {
                                    Image(systemName: "chevron.left")
                                        .font(.body.weight(.semibold))
                                }
                                .opacity(currentIndex > 0 ? 1 : 0.3)
                                .disabled(currentIndex == 0)

                                Text("\(currentIndex + 1) of \(previewItems.count)")

                                Button(action: { withAnimation { currentIndex += 1 } }) {
                                    Image(systemName: "chevron.right")
                                        .font(.body.weight(.semibold))
                                }
                                .opacity(currentIndex < previewItems.count - 1 ? 1 : 0.3)
                                .disabled(currentIndex >= previewItems.count - 1)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.black.opacity(0.5)))
                            .gesture(
                                DragGesture(minimumDistance: 30)
                                    .onEnded { value in
                                        withAnimation {
                                            if value.translation.width < 0 && currentIndex < previewItems.count - 1 {
                                                currentIndex += 1
                                            } else if value.translation.width > 0 && currentIndex > 0 {
                                                currentIndex -= 1
                                            }
                                        }
                                    }
                            )

                            Spacer()
                        }
                        .padding(.top, 60)

                        Spacer()

                        // File info
                        if currentIndex < previewItems.count {
                            Text(previewItems[currentIndex].filename)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Capsule().fill(Color.black.opacity(0.5)))
                                .padding(.bottom, 40)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .task {
            await loadPreviews()
        }
    }

    private func loadPreviews() async {
        isLoading = true
        var items: [PreviewItem] = []

        for file in files {
            do {
                // Load detections
                let result = try await APIService.shared.listDetections(fileId: file.id)

                if file.fileType == .image {
                    // Load image and apply redactions
                    let data = try await APIService.shared.getFileOriginal(file.id)
                    if let originalImage = UIImage(data: data) {
                        if let redactedImage = RedactionService.shared.applyRedactions(
                            to: originalImage,
                            detections: result.detections,
                            manualRedactions: result.manualRedactions
                        ) {
                            items.append(PreviewItem(
                                filename: file.filename,
                                image: redactedImage
                            ))
                        }
                    }
                } else if file.fileType == .pdf {
                    // Load PDF and render pages with redactions
                    let data = try await APIService.shared.getFileOriginal(file.id)
                    if let document = PDFDocument(data: data) {
                        for pageIndex in 0..<document.pageCount {
                            if let page = document.page(at: pageIndex) {
                                let pageDetections = result.detections.filter { $0.pageNumber == pageIndex + 1 }
                                let pageRedactions = result.manualRedactions.filter { $0.pageNumber == pageIndex + 1 }

                                let pageImage = renderPDFPage(page)
                                if let redactedImage = RedactionService.shared.applyRedactions(
                                    to: pageImage,
                                    detections: pageDetections,
                                    manualRedactions: pageRedactions
                                ) {
                                    items.append(PreviewItem(
                                        filename: "\(file.filename) - Page \(pageIndex + 1)",
                                        image: redactedImage
                                    ))
                                }
                            }
                        }
                    }
                }
            } catch {
                // Skip files that fail to load
                continue
            }
        }

        previewItems = items
        isLoading = false
    }

    private func renderPDFPage(_ page: PDFPage) -> UIImage {
        let bounds = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0
        let size = CGSize(width: bounds.width * scale, height: bounds.height * scale)

        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else {
            return UIImage()
        }

        context.setFillColor(UIColor.white.cgColor)
        context.fill(CGRect(origin: .zero, size: size))

        context.translateBy(x: 0, y: size.height)
        context.scaleBy(x: scale, y: -scale)

        page.draw(with: .mediaBox, to: context)

        let image = UIGraphicsGetImageFromCurrentImageContext() ?? UIImage()
        UIGraphicsEndImageContext()
        return image
    }
}

struct PreviewItem {
    let filename: String
    let image: UIImage
}

struct PreviewPageView: View {
    let item: PreviewItem

    var body: some View {
        Image(uiImage: item.image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .padding()
    }
}

#Preview {
    CollectionPreviewView(files: [])
}
