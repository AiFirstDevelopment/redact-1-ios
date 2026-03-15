import SwiftUI

struct ArchivedRequestDetailView: View {
    let requestId: String

    @EnvironmentObject var authService: AuthService
    @State private var request: RecordsRequest?
    @State private var file: EvidenceFile?
    @State private var hasRedactions = false
    @State private var isLoading = false
    @State private var error: String?
    @State private var showingPreview = false
    @State private var showingUnarchiveConfirmation = false
    @State private var isUnarchiving = false
    @Environment(\.dismiss) private var dismiss

    private var isAdmin: Bool {
        authService.currentUser?.role == .supervisor
    }

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

                // File section
                Section("File") {
                    if let file = file {
                        FileRow(file: file)
                    } else {
                        Text("No file uploaded")
                            .foregroundStyle(.secondary)
                    }
                }

                // Actions section
                Section("Actions") {
                    Button(action: { showingPreview = true }) {
                        Label("Preview Redacted", systemImage: "eye")
                    }
                    .disabled(file == nil || !hasRedactions)

                    if isAdmin {
                        Button(action: { showingUnarchiveConfirmation = true }) {
                            Label("Unarchive Request", systemImage: "arrow.uturn.backward")
                        }
                        .disabled(isUnarchiving)
                    }
                }
            }
        }
        .navigationTitle(request?.title ?? "Archived Request")
        .refreshable {
            await loadData()
        }
        .fullScreenCover(isPresented: $showingPreview) {
            if let file = file {
                CollectionPreviewView(files: [file])
            }
        }
        .confirmationDialog("Unarchive Request", isPresented: $showingUnarchiveConfirmation, titleVisibility: .visible) {
            Button("Unarchive") {
                Task { await unarchiveRequest() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will restore the request to the active list.")
        }
        .task {
            await loadData()
        }
    }

    private func loadData() async {
        isLoading = true
        error = nil
        hasRedactions = false

        do {
            async let requestTask = APIService.shared.getRequest(requestId)
            async let filesTask = APIService.shared.listFiles(requestId: requestId)

            request = try await requestTask
            let files = try await filesTask
            file = files.first

            // Check if there are any redactions
            if let currentFile = file {
                let result = try await APIService.shared.listDetections(fileId: currentFile.id)
                hasRedactions = !result.detections.isEmpty || !result.manualRedactions.isEmpty
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func unarchiveRequest() async {
        isUnarchiving = true
        do {
            _ = try await APIService.shared.unarchiveRequest(requestId)
            await MainActor.run {
                dismiss()
            }
        } catch {
            self.error = error.localizedDescription
        }
        isUnarchiving = false
    }
}

#Preview {
    NavigationStack {
        ArchivedRequestDetailView(requestId: "test-id")
    }
    .environmentObject(AuthService.shared)
}
