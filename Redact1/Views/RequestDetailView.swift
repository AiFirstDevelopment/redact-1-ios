import SwiftUI

struct RequestDetailView: View {
    let requestId: String

    @EnvironmentObject var authService: AuthService
    @State private var request: RecordsRequest?
    @State private var files: [EvidenceFile] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var showingUploadSheet = false
    @State private var showingExportSheet = false
    @State private var showingStatusPicker = false
    @State private var showingReassignSheet = false

    private var isAdmin: Bool {
        authService.currentUser?.role == .admin
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
                                    if let badge = user.badgeNumber, !badge.isEmpty {
                                        Text("Badge: \(badge)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
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
