import Foundation

struct EvidenceFile: Codable, Identifiable {
    let id: String
    let requestId: String
    let filename: String
    let fileType: FileType
    let mimeType: String
    let fileSize: Int
    let originalR2Key: String
    let redactedR2Key: String?
    let status: FileStatus
    let uploadedBy: String
    let deletedAt: Int?
    let createdAt: Int
    let updatedAt: Int

    enum CodingKeys: String, CodingKey {
        case id, filename, status
        case requestId = "request_id"
        case fileType = "file_type"
        case mimeType = "mime_type"
        case fileSize = "file_size"
        case originalR2Key = "original_r2_key"
        case redactedR2Key = "redacted_r2_key"
        case uploadedBy = "uploaded_by"
        case deletedAt = "deleted_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(fileSize))
    }
}

enum FileType: String, Codable {
    case image
    case pdf
}

enum FileStatus: String, Codable {
    case uploaded
    case processing
    case detected
    case reviewed
    case exported

    var displayName: String {
        switch self {
        case .uploaded: return "Uploaded"
        case .processing: return "Processing"
        case .detected: return "Detected"
        case .reviewed: return "Reviewed"
        case .exported: return "Exported"
        }
    }
}
