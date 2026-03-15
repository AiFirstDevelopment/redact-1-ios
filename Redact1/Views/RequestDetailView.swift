import SwiftUI

struct RequestDetailView: View {
    let requestId: String

    @EnvironmentObject var authService: AuthService
    @State private var request: RecordsRequest?
    @State private var file: EvidenceFile?
    @State private var isLoading = false
    @State private var error: String?
    @State private var showingUploadSheet = false
    @State private var showingExportSheet = false
    @State private var showingStatusPicker = false
    @State private var showingReassignSheet = false
    @State private var showingArchiveConfirmation = false
    @State private var showingPreview = false
    @State private var showingDeleteConfirmation = false
    @State private var isArchiving = false

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
                        Button(action: { showingStatusPicker = true }) {
                            HStack {
                                StatusBadge(status: request.status)
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    if let notes = request.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notes")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(notes)
                        }
                    }

                    if isAdmin {
                        Button(action: { showingReassignSheet = true }) {
                            Label("Reassign Request", systemImage: "person.badge.plus")
                        }
                    }
                }

                // File section
                Section("File") {
                    if let file = file {
                        NavigationLink(destination: fileDestination(for: file)) {
                            FileRow(file: file)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                showingDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    } else {
                        Button(action: { showingUploadSheet = true }) {
                            Label("Upload PDF", systemImage: "doc.badge.plus")
                        }
                    }
                }

                // Actions section
                Section("Actions") {
                    Button(action: { showingPreview = true }) {
                        Label("Preview Redacted", systemImage: "eye")
                    }
                    .disabled(file == nil)

                    Button(action: { showingExportSheet = true }) {
                        Label("Export Redacted", systemImage: "square.and.arrow.up")
                    }
                    .disabled(file == nil)

                    if isAdmin {
                        Button(action: { showingArchiveConfirmation = true }) {
                            Label("Archive Request", systemImage: "archivebox")
                        }
                        .disabled(isArchiving)
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
                file = newFile
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            if let request = request, let file = file {
                ExportView(request: request, files: [file])
            }
        }
        .fullScreenCover(isPresented: $showingPreview) {
            if let file = file {
                CollectionPreviewView(files: [file])
            }
        }
        .confirmationDialog("Delete File?", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task { await deleteFile() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
        .task {
            await loadData()
        }
        .confirmationDialog("Change Status", isPresented: $showingStatusPicker, titleVisibility: .visible) {
            ForEach(RequestStatus.allCases, id: \.self) { status in
                Button(status.displayName) {
                    Task { await updateStatus(status) }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showingReassignSheet) {
            if let request = request {
                ReassignRequestView(request: request) { updatedRequest in
                    self.request = updatedRequest
                }
            }
        }
        .confirmationDialog("Archive Request", isPresented: $showingArchiveConfirmation, titleVisibility: .visible) {
            Button("Archive", role: .destructive) {
                Task { await archiveRequest() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will move the request to the archive. Supervisors can restore it later.")
        }
    }

    private func archiveRequest() async {
        guard let currentRequest = request else { return }

        isArchiving = true
        do {
            _ = try await APIService.shared.archiveRequest(currentRequest.id)
            // Navigate back after archiving
            request = nil
        } catch {
            self.error = error.localizedDescription
        }
        isArchiving = false
    }

    private func updateStatus(_ newStatus: RequestStatus) async {
        guard let currentRequest = request else { return }

        do {
            let updated = try await APIService.shared.updateRequest(
                currentRequest.id,
                body: UpdateRequestBody(status: newStatus)
            )
            request = updated
        } catch {
            self.error = error.localizedDescription
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
            let files = try await filesTask
            file = files.first
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func deleteFile() async {
        guard let currentFile = file else { return }

        do {
            try await APIService.shared.deleteFile(currentFile.id)
            file = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct ReassignRequestView: View {
    @Environment(\.dismiss) private var dismiss
    let request: RecordsRequest
    var onSave: ((RecordsRequest) -> Void)?

    @State private var users: [User] = []
    @State private var selectedUserId: String?
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            List {
                if isLoading && users.isEmpty {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if users.isEmpty {
                    Text("No users available")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(users) { user in
                        Button {
                            selectedUserId = user.id
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(user.name)
                                        .font(.headline)
                                    Text(user.email)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if selectedUserId == user.id || (selectedUserId == nil && user.id == request.createdBy) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }

                if let error = error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Reassign Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await reassign() }
                    }
                    .disabled(selectedUserId == nil || selectedUserId == request.createdBy || isLoading)
                }
            }
            .task {
                await loadUsers()
            }
        }
    }

    private func loadUsers() async {
        isLoading = true
        do {
            users = try await APIService.shared.listUsers()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func reassign() async {
        guard let userId = selectedUserId else { return }

        isLoading = true
        error = nil

        do {
            let updated = try await APIService.shared.updateRequest(
                request.id,
                body: UpdateRequestBody(createdBy: userId)
            )
            onSave?(updated)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        RequestDetailView(requestId: "test-id")
    }
    .environmentObject(AuthService.shared)
}
