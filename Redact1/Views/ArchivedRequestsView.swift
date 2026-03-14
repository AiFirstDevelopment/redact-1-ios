import SwiftUI

struct ArchivedRequestsView: View {
    @State private var requests: [RecordsRequest] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var searchText = ""

    var filteredRequests: [RecordsRequest] {
        if searchText.isEmpty {
            return requests
        }
        return requests.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.requestNumber.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            if isLoading && requests.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            } else if let error = error {
                VStack(spacing: 8) {
                    Text("Error loading archived requests")
                        .font(.headline)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Retry") {
                        Task { await loadRequests() }
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            } else if filteredRequests.isEmpty {
                ContentUnavailableView(
                    "No Archived Requests",
                    systemImage: "archivebox",
                    description: Text("Archived requests will appear here")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(filteredRequests) { request in
                    ArchivedRequestRow(request: request, onUnarchive: { unarchived in
                        if let idx = requests.firstIndex(where: { $0.id == unarchived.id }) {
                            requests.remove(at: idx)
                        }
                    })
                }
            }
        }
        .navigationTitle("Archived")
        .searchable(text: $searchText, prompt: "Search archived requests")
        .refreshable {
            await loadRequests()
        }
        .task {
            await loadRequests()
        }
    }

    private func loadRequests() async {
        isLoading = true
        error = nil

        do {
            requests = try await APIService.shared.listArchivedRequests()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}

struct ArchivedRequestRow: View {
    let request: RecordsRequest
    var onUnarchive: ((RecordsRequest) -> Void)?

    @State private var showingUnarchiveConfirmation = false
    @State private var isUnarchiving = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(request.title)
                    .font(.headline)
                Spacer()
                StatusBadge(status: request.status)
            }

            HStack {
                Text(request.requestNumber)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(request.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing) {
            Button {
                showingUnarchiveConfirmation = true
            } label: {
                Label("Unarchive", systemImage: "arrow.uturn.backward")
            }
            .tint(.blue)
        }
        .confirmationDialog("Unarchive Request", isPresented: $showingUnarchiveConfirmation, titleVisibility: .visible) {
            Button("Unarchive") {
                Task { await unarchive() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will restore the request to the active list.")
        }
        .disabled(isUnarchiving)
    }

    private func unarchive() async {
        isUnarchiving = true
        do {
            let unarchived = try await APIService.shared.unarchiveRequest(request.id)
            onUnarchive?(unarchived)
        } catch {
            // Handle error silently or show alert
        }
        isUnarchiving = false
    }
}

#Preview {
    NavigationStack {
        ArchivedRequestsView()
    }
    .environmentObject(AuthService.shared)
}
