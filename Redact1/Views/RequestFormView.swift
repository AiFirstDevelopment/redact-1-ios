import SwiftUI

struct RequestFormView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var requestNumber = ""
    @State private var title = ""
    @State private var requestDate = Date()
    @State private var notes = ""
    @State private var isLoading = false
    @State private var error: String?

    var onSave: ((RecordsRequest) -> Void)?

    var body: some View {
        NavigationStack {
            Form {
                Section("Request Information") {
                    TextField("Request Number", text: $requestNumber)
                        .autocapitalization(.allCharacters)

                    TextField("Title", text: $title)

                    DatePicker("Request Date", selection: $requestDate, displayedComponents: .date)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
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
        }
    }

    private func createRequest() async {
        isLoading = true
        error = nil

        let body = CreateRequestBody(
            requestNumber: requestNumber,
            title: title,
            requestDate: Int(requestDate.timeIntervalSince1970),
            notes: notes.isEmpty ? nil : notes
        )

        do {
            let request = try await APIService.shared.createRequest(body)
            onSave?(request)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    RequestFormView()
}
