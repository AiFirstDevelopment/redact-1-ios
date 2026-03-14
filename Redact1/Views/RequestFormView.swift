import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct PendingFile: Identifiable {
    let id = UUID()
    let name: String
    let data: Data
    let mimeType: String
}

struct RequestFormView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    @State private var requestNumber = ""
    @State private var title = ""
    @State private var requestDate = Date()
    @State private var notes = ""
    @State private var isLoading = false
    @State private var error: String?
    @State private var users: [User] = []
    @State private var selectedUserId: String?
    @State private var pendingFiles: [PendingFile] = []
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isShowingDocumentPicker = false
    @FocusState private var focusedField: Field?

    enum Field {
        case requestNumber, title, notes
    }

    private var isSupervisor: Bool {
        authService.currentUser?.role == .supervisor
    }

    var onSave: ((RecordsRequest) -> Void)?

    private static func generateRequestNumber() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let dateStr = formatter.string(from: Date())
        let random = String(format: "%03d", Int.random(in: 1...999))
        return "RR-\(dateStr)-\(random)"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Request Information") {
                    HStack {
                        TextField("Request Number", text: $requestNumber)
                            .textInputAutocapitalization(.characters)
                            .focused($focusedField, equals: .requestNumber)

                        if requestNumber.isEmpty {
                            Button("Generate") {
                                requestNumber = Self.generateRequestNumber()
                            }
                            .buttonStyle(.bordered)
                            .font(.caption)
                        }
                    }

                    TextField("Title", text: $title)
                        .focused($focusedField, equals: .title)

                    DatePicker("Request Date", selection: $requestDate, displayedComponents: .date)

                    if isSupervisor && !users.isEmpty {
                        Picker("Assign To", selection: $selectedUserId) {
                            Text("Myself").tag(nil as String?)
                            ForEach(users) { user in
                                Text(user.name).tag(user.id as String?)
                            }
                        }
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                        .focused($focusedField, equals: .notes)
                }

                Section {
                    if pendingFiles.isEmpty {
                        Text("No files added yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(pendingFiles) { file in
                            HStack {
                                Image(systemName: file.mimeType == "application/pdf" ? "doc.fill" : "photo.fill")
                                    .foregroundStyle(.blue)
                                Text(file.name)
                                Spacer()
                                Button {
                                    pendingFiles.removeAll { $0.id == file.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }

                    HStack(spacing: 16) {
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            Label("Photo", systemImage: "photo")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            isShowingDocumentPicker = true
                        } label: {
                            Label("PDF", systemImage: "doc")
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                } header: {
                    Text("Files to Redact")
                }

                if let error = error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await createRequest() }
                    }
                    .disabled(requestNumber.isEmpty || title.isEmpty || isLoading)
                }
            }
            .disabled(isLoading)
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
            .onAppear {
                if requestNumber.isEmpty {
                    requestNumber = Self.generateRequestNumber()
                }
            }
            .task {
                if isSupervisor {
                    do {
                        users = try await APIService.shared.listUsers()
                    } catch {
                        // Ignore - picker just won't show
                    }
                }
            }
            .onChange(of: selectedPhotoItem) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        let filename = "image_\(Int(Date().timeIntervalSince1970)).jpg"
                        pendingFiles.append(PendingFile(name: filename, data: data, mimeType: "image/jpeg"))
                        selectedPhotoItem = nil
                    }
                }
            }
            .fileImporter(
                isPresented: $isShowingDocumentPicker,
                allowedContentTypes: [UTType.pdf],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    for url in urls {
                        guard url.startAccessingSecurityScopedResource() else {
                            error = "Unable to access file: \(url.lastPathComponent)"
                            continue
                        }
                        defer { url.stopAccessingSecurityScopedResource() }
                        do {
                            let data = try Data(contentsOf: url)
                            pendingFiles.append(PendingFile(name: url.lastPathComponent, data: data, mimeType: "application/pdf"))
                        } catch {
                            self.error = "Failed to read file: \(url.lastPathComponent)"
                        }
                    }
                case .failure(let err):
                    error = "File selection failed: \(err.localizedDescription)"
                }
            }
        }
    }

    private func createRequest() async {
        isLoading = true
        error = nil

        let body = CreateRequestBody(
            requestNumber: requestNumber,
            title: title,
            requestDate: Int(requestDate.timeIntervalSince1970),
            notes: notes.isEmpty ? nil : notes,
            assignTo: selectedUserId
        )

        do {
            let request = try await APIService.shared.createRequest(body)

            // Upload any pending files
            for file in pendingFiles {
                do {
                    _ = try await APIService.shared.uploadFile(
                        requestId: request.id,
                        fileData: file.data,
                        filename: file.name,
                        mimeType: file.mimeType
                    )
                } catch {
                    self.error = "Failed to upload \(file.name): \(error.localizedDescription)"
                    isLoading = false
                    return
                }
            }

            onSave?(request)
            dismiss()
        } catch let apiError as APIError {
            self.error = apiError.localizedDescription
        } catch {
            self.error = "Unexpected error: \(error.localizedDescription)"
        }

        isLoading = false
    }
}

#Preview {
    RequestFormView()
}
