import SwiftUI

struct ExportView: View {
    @Environment(\.dismiss) private var dismiss
    let request: RecordsRequest
    let files: [EvidenceFile]

    @State private var isExporting = false
    @State private var exportComplete = false
    @State private var error: String?
    @State private var exportedFiles: [(name: String, url: URL)] = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if isExporting {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Preparing export...")
                            .font(.headline)
                        Text("Applying redactions to \(files.count) file(s)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if exportComplete {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.green)

                        Text("Export Complete")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("\(exportedFiles.count) file(s) ready")
                            .foregroundStyle(.secondary)

                        ShareLink(items: exportedFiles.map { $0.url }) {
                            Label("Share Files", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)

                        Text("Export Redacted Files")
                            .font(.title2)
                            .fontWeight(.bold)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Request: \(request.requestNumber)")
                            Text("Files to export: \(files.count)")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                        List {
                            ForEach(files) { file in
                                HStack {
                                    Image(systemName: file.fileType == .image ? "photo" : "doc.text")
                                    Text(file.filename)
                                    Spacer()
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                        .frame(maxHeight: 200)

                        Button(action: startExport) {
                            Label("Start Export", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                if let error = error {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .padding()
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func startExport() {
        isExporting = true
        error = nil

        Task {
            do {
                // Create export on server
                let (_, _) = try await APIService.shared.createExport(requestId: request.id)

                // Download redacted files and save to temp directory
                var downloadedFiles: [(name: String, url: URL)] = []
                let tempDir = FileManager.default.temporaryDirectory

                for file in files {
                    let data = try await APIService.shared.getFileRedacted(file.id)
                    let tempURL = tempDir.appendingPathComponent(file.filename)
                    try data.write(to: tempURL)
                    downloadedFiles.append((file.filename, tempURL))
                }

                exportedFiles = downloadedFiles
                exportComplete = true
            } catch {
                self.error = error.localizedDescription
            }

            isExporting = false
        }
    }
}

#Preview {
    ExportView(
        request: RecordsRequest(
            id: "1",
            requestNumber: "FOIA-2024-001",
            title: "Test Request",
            requestDate: Int(Date().timeIntervalSince1970),
            notes: nil,
            status: .inProgress,
            createdBy: "user",
            archivedAt: nil,
            createdAt: 0,
            updatedAt: 0
        ),
        files: []
    )
}
