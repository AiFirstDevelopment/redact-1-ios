import Foundation

struct RecordsRequest: Codable, Identifiable {
    let id: String
    let requestNumber: String
    let title: String
    let requestDate: Int
    let notes: String?
    let status: RequestStatus
    let createdBy: String
    let archivedAt: Int?
    let createdAt: Int
    let updatedAt: Int

    enum CodingKeys: String, CodingKey {
        case id, title, notes, status
        case requestNumber = "request_number"
        case requestDate = "request_date"
        case createdBy = "created_by"
        case archivedAt = "archived_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var isArchived: Bool {
        archivedAt != nil
    }

    var formattedDate: String {
        let date = Date(timeIntervalSince1970: TimeInterval(requestDate))
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

enum RequestStatus: String, Codable, CaseIterable {
    case new
    case inProgress = "in_progress"
    case completed

    var displayName: String {
        switch self {
        case .new: return "New"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        }
    }

    var color: String {
        switch self {
        case .new: return "blue"
        case .inProgress: return "orange"
        case .completed: return "green"
        }
    }
}

struct CreateRequestBody: Codable {
    let requestNumber: String
    let title: String
    let requestDate: Int
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case title, notes
        case requestNumber = "request_number"
        case requestDate = "request_date"
    }
}

struct UpdateRequestBody: Codable {
    var title: String?
    var notes: String?
    var status: RequestStatus?
    var createdBy: String?

    enum CodingKeys: String, CodingKey {
        case title, notes, status
        case createdBy = "created_by"
    }
}
