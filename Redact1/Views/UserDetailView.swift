import SwiftUI

struct UserDetailView: View {
    let user: User

    @Environment(\.dismiss) private var dismiss
    @State private var requests: [RecordsRequest] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var showingEditSheet = false
    @State private var editedUser: User?

    var body: some View {
        List {
            Section("User Information") {
                LabeledContent("Name", value: user.name)
                LabeledContent("Email", value: user.email)
                LabeledContent("Created", value: formatDate(user.createdAt))
            }

            Section("Assigned Requests") {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else if requests.isEmpty {
                    Text("No requests assigned")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(requests) { request in
                        NavigationLink(destination: RequestDetailView(requestId: request.id)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(request.title)
                                        .font(.headline)
                                    Text(request.requestNumber)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                StatusBadge(status: request.status)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(editedUser?.name ?? user.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditUserView(user: editedUser ?? user) { updatedUser in
                editedUser = updatedUser
            }
        }
        .alert("Error", isPresented: .constant(error != nil)) {
            Button("OK") { error = nil }
        } message: {
            Text(error ?? "")
        }
        .task {
            await loadRequests()
        }
    }

    private func loadRequests() async {
        isLoading = true
        do {
            requests = try await APIService.shared.getUserRequests(user.id)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func formatDate(_ timestamp: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct EditUserView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authService: AuthService
    let user: User
    var onSave: ((User) -> Void)?

    @State private var name: String
    @State private var email: String
    @State private var role: UserRole
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var error: String?

    private var isAdmin: Bool {
        authService.currentUser?.role == .supervisor
    }

    init(user: User, onSave: ((User) -> Void)? = nil) {
        self.user = user
        self.onSave = onSave
        _name = State(initialValue: user.name)
        _email = State(initialValue: user.email)
        _role = State(initialValue: user.role)
    }

    var passwordsMatch: Bool {
        password.isEmpty || password == confirmPassword
    }

    var hasChanges: Bool {
        name != user.name || email != user.email || role != user.role || !password.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("User Information") {
                    TextField("Name", text: $name)

                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)

                    if isAdmin {
                        Picker("Role", selection: $role) {
                            ForEach(UserRole.allCases, id: \.self) { role in
                                Text(role.displayName).tag(role)
                            }
                        }
                    }
                }

                Section("Change Password") {
                    SecureField("New Password (leave blank to keep)", text: $password)
                        .textContentType(.newPassword)

                    if !password.isEmpty {
                        SecureField("Confirm Password", text: $confirmPassword)
                            .textContentType(.newPassword)

                        if !passwordsMatch {
                            Text("Passwords do not match")
                                .foregroundStyle(.red)
                                .font(.caption)
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
            .navigationTitle("Edit User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await saveUser() }
                    }
                    .disabled(!hasChanges || !passwordsMatch || name.isEmpty || email.isEmpty || isLoading)
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

    private func saveUser() async {
        isLoading = true
        error = nil

        do {
            let updatedUser = try await APIService.shared.updateUser(
                user.id,
                name: name != user.name ? name : nil,
                email: email != user.email ? email : nil,
                password: password.isEmpty ? nil : password,
                role: (isAdmin && role != user.role) ? role : nil
            )
            onSave?(updatedUser)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        UserDetailView(user: User(
            id: "test-123",
            email: "clerk@pd.local",
            name: "Clerk Smith",
            role: .clerk,
            createdAt: 1234567890,
            updatedAt: 1234567890
        ))
    }
    .environmentObject(AuthService.shared)
}
