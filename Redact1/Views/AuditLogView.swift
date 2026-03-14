import SwiftUI

struct AuditLogEntry: Codable, Identifiable {
    let id: String
    let userId: String?
    let userName: String?
    let action: String
    let entityType: String
    let entityId: String
    let details: String?
    let createdAt: Int

    enum CodingKeys: String, CodingKey {
        case id, action, details
        case userId = "user_id"
        case userName = "user_name"
        case entityType = "entity_type"
        case entityId = "entity_id"
        case createdAt = "created_at"
    }

    var formattedDate: String {
        let date = Date(timeIntervalSince1970: TimeInterval(createdAt))
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }

    var actionIcon: String {
        switch action {
        case "create": return "plus.circle"
        case "update": return "pencil.circle"
        case "delete": return "trash.circle"
        case "upload": return "arrow.up.circle"
        case "upload_redacted": return "checkmark.circle"
        case "detect": return "wand.and.stars"
        case "review_detection": return "eye.circle"
        case "add_manual_redaction": return "rectangle.badge.plus"
        case "delete_manual_redaction": return "rectangle.badge.minus"
        case "export": return "square.and.arrow.up.circle"
        case "login": return "person.badge.key"
        case "logout": return "person.badge.minus"
        default: return "circle"
        }
    }
}

struct AuditLogView: View {
    let requestId: String

    @State private var logs: [AuditLogEntry] = []
    @State private var isLoading = false
    @State private var error: String?

    var body: some View {
        List {
            if isLoading && logs.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            } else if logs.isEmpty {
                ContentUnavailableView(
                    "No Activity",
                    systemImage: "list.bullet.clipboard",
                    description: Text("No audit logs for this request")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(logs) { log in
                    AuditLogRow(log: log)
                }
            }
        }
        .navigationTitle("Audit Trail")
        .refreshable {
            await loadLogs()
        }
        .task {
            await loadLogs()
        }
    }

    private func loadLogs() async {
        isLoading = true
        error = nil

        do {
            let data = try await APIService.shared.listDetections(fileId: requestId)
            // Note: This is a placeholder - actual audit log API would be different
            // For now, we'll show an empty state
        } catch {
            // Expected for now
        }

        isLoading = false
    }
}

struct AuditLogRow: View {
    let log: AuditLogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: log.actionIcon)
                .foregroundStyle(.blue)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(log.action.replacingOccurrences(of: "_", with: " ").capitalized)
                        .font(.headline)
                    Spacer()
                    Text(log.formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    if let userName = log.userName {
                        Text(userName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text(log.entityType)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                }

                if let details = log.details {
                    Text(details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        AuditLogView(requestId: "test-id")
    }
}
