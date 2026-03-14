import Foundation

struct RecordsRequest: Codable, Identifiable {
    let id: String
    let requestNumber: String
    let title: String
    let requestDate: Int
    let notes: String?
    let status: RequestStatus
    let createdBy: String
    let createdAt: Int
    let updatedAt: Int

    enum CodingKeys: String, CodingKey {
        case id, title, notes, status
        case requestNumber = "request_number"
        case requestDate = "request_date"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
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
    case processing
    case review
    case exported

    var displayName: String {
        switch self {
        case .new: return "New"
        case .processing: return "Processing"
        case .review: return "Review"
        case .exported: return "Exported"
        }
    }

    var color: String {
        switch self {
        case .new: return "blue"
        case .processing: return "orange"
        case .review: return "purple"
        case .exported: return "green"
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
}
