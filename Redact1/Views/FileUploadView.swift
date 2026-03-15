import SwiftUI
import UniformTypeIdentifiers

struct FileUploadView: View {
    @Environment(\.dismiss) private var dismiss
    let requestId: String
    var onUpload: ((EvidenceFile) -> Void)?

    @State private var isShowingDocumentPicker = false
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0
    @State private var error: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // PDF picker
                Button(action: { isShowingDocumentPicker = true }) {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                        Text("Select PDF")
                            .font(.headline)
                        Text("PDF documents")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .foregroundStyle(.primary)

                Spacer()

                if isUploading {
                    VStack(spacing: 8) {
                        ProgressView(value: uploadProgress)
                        Text("Uploading...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }

                if let error = error {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                        .padding()
                }
            }
            .padding()
            .navigationTitle("Upload File")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .disabled(isUploading)
            .fileImporter(
                isPresented: $isShowingDocumentPicker,
                allowedContentTypes: [UTType.pdf],
                allowsMultipleSelection: false
            ) { result in
                Task {
                    await handleDocumentSelection(result)
                }
            }
        }
    }

    private func handleDocumentSelection(_ result: Result<[URL], Error>) async {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            isUploading = true
            uploadProgress = 0.3
            error = nil

            do {
                guard url.startAccessingSecurityScopedResource() else {
                    throw UploadError.accessDenied
                }
                defer { url.stopAccessingSecurityScopedResource() }

                let data = try Data(contentsOf: url)
                uploadProgress = 0.6

                let file = try await APIService.shared.uploadFile(
                    requestId: requestId,
                    fileData: data,
                    filename: url.lastPathComponent,
                    mimeType: "application/pdf"
                )

                uploadProgress = 1.0
                onUpload?(file)
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }

            isUploading = false

        case .failure(let error):
            self.error = error.localizedDescription
        }
    }
}

enum UploadError: Error, LocalizedError {
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .accessDenied: return "Unable to access the selected file"
        }
    }
}

#Preview {
    FileUploadView(requestId: "test-id")
}
