import SwiftUI

struct RequestListView: View {
    @State private var requests: [RecordsRequest] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var searchText = ""
    @State private var selectedStatus: RequestStatus?
    @State private var showingCreateSheet = false

    var filteredRequests: [RecordsRequest] {
        var result = requests

        if let status = selectedStatus {
            result = result.filter { $0.status == status }
        }

        if !searchText.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.requestNumber.localizedCaseInsensitiveContains(searchText)
            }
        }

        return result
    }

    var body: some View {
        List {
            if isLoading && requests.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            } else if let error = error {
                VStack(spacing: 8) {
                    Text("Error loading requests")
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
                    "No Requests",
                    systemImage: "doc.text",
                    description: Text("Create a new request to get started")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(filteredRequests) { request in
                    NavigationLink(destination: RequestDetailView(requestId: request.id)) {
                        RequestRow(request: request)
                    }
                }
                .onDelete(perform: deleteRequests)
            }
        }
        .navigationTitle("Requests")
        .searchable(text: $searchText, prompt: "Search requests")
        .refreshable {
            await loadRequests()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showingCreateSheet = true }) {
                    Image(systemName: "plus")
                }
            }

            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button("All") { selectedStatus = nil }
                    ForEach(RequestStatus.allCases, id: \.self) { status in
                        Button(status.displayName) { selectedStatus = status }
                    }
                } label: {
                    HStack {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        if let status = selectedStatus {
                            Text(status.displayName)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            RequestFormView { newRequest in
                requests.insert(newRequest, at: 0)
            }
        }
        .task {
            await loadRequests()
        }
    }

    private func loadRequests() async {
        isLoading = true
        error = nil

        do {
            requests = try await APIService.shared.listRequests()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    private func deleteRequests(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let request = filteredRequests[index]
                do {
                    try await APIService.shared.deleteRequest(request.id)
                    if let idx = requests.firstIndex(where: { $0.id == request.id }) {
                        requests.remove(at: idx)
                    }
                } catch {
                    self.error = error.localizedDescription
                }
            }
        }
    }
}

struct RequestRow: View {
    let request: RecordsRequest

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
    }
}

struct StatusBadge: View {
    let status: RequestStatus

    var backgroundColor: Color {
        switch status {
        case .new: return .blue
        case .processing: return .orange
        case .review: return .purple
        case .exported: return .green
        }
    }

    var body: some View {
        Text(status.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor.opacity(0.2))
            .foregroundStyle(backgroundColor)
            .clipShape(Capsule())
    }
}

#Preview {
    NavigationStack {
        RequestListView()
    }
    .environmentObject(AuthService.shared)
}
