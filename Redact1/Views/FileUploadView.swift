import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import Photos

struct FileUploadView: View {
    @Environment(\.dismiss) private var dismiss
    let requestId: String
    var onUpload: ((EvidenceFile) -> Void)?

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isShowingDocumentPicker = false
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0
    @State private var error: String?
    @State private var photoAccessStatus: PHAuthorizationStatus = .notDetermined

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Photo access info banner
                if photoAccessStatus == .limited {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Limited photo access. Tap to grant full access.")
                            .font(.caption)
                        Spacer()
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onTapGesture {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }

                Spacer()

                // Image picker
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 48))
                        Text("Select Image")
                            .font(.headline)
                        Text("JPG, PNG")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .onChange(of: selectedPhotoItem) { _, newValue in
                    Task {
                        if let data = try? await newValue?.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            selectedImage = image
                            await uploadImage(data: data)
                        }
                    }
                }

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
            .onAppear {
                requestPhotoAccess()
            }
        }
    }

    private func requestPhotoAccess() {
        photoAccessStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        if photoAccessStatus == .notDetermined {
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                DispatchQueue.main.async {
                    photoAccessStatus = status
                }
            }
        }
    }

    private func uploadImage(data: Data) async {
        isUploading = true
        uploadProgress = 0.3
        error = nil

        do {
            let filename = "image_\(Date().timeIntervalSince1970).jpg"
            uploadProgress = 0.6

            let file = try await APIService.shared.uploadFile(
                requestId: requestId,
                fileData: data,
                filename: filename,
                mimeType: "image/jpeg"
            )

            uploadProgress = 1.0
            onUpload?(file)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isUploading = false
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
