import SwiftUI

struct RequestDetailView: View {
    let requestId: String

    @State private var request: RecordsRequest?
    @State private var files: [EvidenceFile] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var showingUploadSheet = false
    @State private var showingExportSheet = false

    var body: some View {
        List {
            if isLoading && request == nil {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            } else if let request = request {
                // Request info section
                Section("Request Details") {
                    LabeledContent("Number", value: request.requestNumber)
                    LabeledContent("Date", value: request.formattedDate)
                    LabeledContent("Status") {
                        StatusBadge(status: request.status)
                    }
                    if let notes = request.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(notes)
                        }
                    }
                }

                // Files section
                Section {
                    if files.isEmpty {
                        ContentUnavailableView(
                            "No Files",
                            systemImage: "doc",
                            description: Text("Upload files to begin redaction")
                        )
                    } else {
                        ForEach(files) { file in
                            NavigationLink(destination: fileDestination(for: file)) {
                                FileRow(file: file)
                            }
                        }
                        .onDelete(perform: deleteFiles)
                    }
                } header: {
                    HStack {
                        Text("Files")
                        Spacer()
                        Button(action: { showingUploadSheet = true }) {
                            Image(systemName: "plus.circle")
                        }
                    }
                }

                // Actions section
                Section("Actions") {
                    Button(action: { showingExportSheet = true }) {
                        Label("Export Redacted Files", systemImage: "square.and.arrow.up")
                    }
                    .disabled(files.filter { $0.status == .reviewed }.isEmpty)

                    NavigationLink(destination: AuditLogView(requestId: requestId)) {
                        Label("View Audit Trail", systemImage: "list.bullet.clipboard")
                    }
                }
            }
        }
        .navigationTitle(request?.title ?? "Request")
        .refreshable {
            await loadData()
        }
        .sheet(isPresented: $showingUploadSheet) {
            FileUploadView(requestId: requestId) { newFile in
                files.insert(newFile, at: 0)
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            if let request = request {
                ExportView(request: request, files: files.filter { $0.status == .reviewed })
            }
        }
        .task {
            await loadData()
        }
    }

    @ViewBuilder
    private func fileDestination(for file: EvidenceFile) -> some View {
        switch file.fileType {
        case .image:
            ImageReviewView(file: file)
        case .pdf:
            PDFReviewView(file: file)
        }
    }

    private func loadData() async {
        isLoading = true
        error = nil

        do {
            async let requestTask = APIService.shared.getRequest(requestId)
            async let filesTask = APIService.shared.listFiles(requestId: requestId)

            request = try await requestTask
            files = try await filesTask
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func deleteFiles(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let file = files[index]
                do {
                    try await APIService.shared.deleteFile(file.id)
                    files.remove(at: index)
                } catch {
                    self.error = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        RequestDetailView(requestId: "test-id")
    }
}
