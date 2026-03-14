import SwiftUI

struct UsersView: View {
    @State private var users: [User] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var showingCreateSheet = false

    var body: some View {
        List {
            if isLoading && users.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            } else if users.isEmpty {
                ContentUnavailableView(
                    "No Users",
                    systemImage: "person.2",
                    description: Text("Create a user to get started")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(users) { user in
                    UserRow(user: user)
                }
            }
        }
        .navigationTitle("Users")
        .refreshable {
            await loadUsers()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showingCreateSheet = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingCreateSheet) {
            CreateUserView { newUser in
                users.append(newUser)
            }
        }
        .task {
            await loadUsers()
        }
    }

    private func loadUsers() async {
        // Note: In a real implementation, there would be a list users endpoint
        // For now, we'll just show the current user
        isLoading = true

        do {
            let currentUser = try await APIService.shared.getCurrentUser()
            users = [currentUser]
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}

struct UserRow: View {
    let user: User

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.title)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text(user.name)
                    .font(.headline)
                Text(user.email)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CreateUserView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var error: String?

    var onSave: ((User) -> Void)?

    var passwordsMatch: Bool {
        !password.isEmpty && password == confirmPassword
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
                }

                Section("Password") {
                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)

                    SecureField("Confirm Password", text: $confirmPassword)
                        .textContentType(.newPassword)

                    if !password.isEmpty && !passwordsMatch {
                        Text("Passwords do not match")
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }

                if let error = error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task { await createUser() }
                    }
                    .disabled(name.isEmpty || email.isEmpty || !passwordsMatch || isLoading)
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

    private func createUser() async {
        isLoading = true
        error = nil

        // Note: This would call a create user API endpoint
        // For now, we'll just show an error
        error = "User creation via API not yet implemented"

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        UsersView()
    }
}
