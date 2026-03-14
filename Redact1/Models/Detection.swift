import Foundation
import CoreGraphics

struct Detection: Codable, Identifiable {
    let id: String
    let fileId: String
    let detectionType: DetectionType
    let bboxX: Double?
    let bboxY: Double?
    let bboxWidth: Double?
    let bboxHeight: Double?
    let pageNumber: Int?
    let textStart: Int?
    let textEnd: Int?
    let textContent: String?
    let confidence: Double?
    var status: DetectionStatus
    let reviewedBy: String?
    let reviewedAt: Int?
    let createdAt: Int

    enum CodingKeys: String, CodingKey {
        case id, confidence, status
        case fileId = "file_id"
        case detectionType = "detection_type"
        case bboxX = "bbox_x"
        case bboxY = "bbox_y"
        case bboxWidth = "bbox_width"
        case bboxHeight = "bbox_height"
        case pageNumber = "page_number"
        case textStart = "text_start"
        case textEnd = "text_end"
        case textContent = "text_content"
        case reviewedBy = "reviewed_by"
        case reviewedAt = "reviewed_at"
        case createdAt = "created_at"
    }

    var boundingBox: CGRect? {
        guard let x = bboxX, let y = bboxY, let w = bboxWidth, let h = bboxHeight else {
            return nil
        }
        return CGRect(x: x, y: y, width: w, height: h)
    }
}

enum DetectionType: String, Codable, CaseIterable {
    case face
    case plate
    case ssn
    case phone
    case email
    case address
    case dob

    var displayName: String {
        switch self {
        case .face: return "Face"
        case .plate: return "License Plate"
        case .ssn: return "SSN"
        case .phone: return "Phone Number"
        case .email: return "Email"
        case .address: return "Address"
        case .dob: return "Date of Birth"
        }
    }

    var iconName: String {
        switch self {
        case .face: return "person.fill"
        case .plate: return "car.fill"
        case .ssn: return "creditcard.fill"
        case .phone: return "phone.fill"
        case .email: return "envelope.fill"
        case .address: return "house.fill"
        case .dob: return "calendar"
        }
    }
}

enum DetectionStatus: String, Codable {
    case pending
    case approved
    case rejected
}

struct ManualRedaction: Codable, Identifiable {
    let id: String
    let fileId: String
    let redactionType: String
    let bboxX: Double?
    let bboxY: Double?
    let bboxWidth: Double?
    let bboxHeight: Double?
    let pageNumber: Int?
    let createdBy: String
    let createdAt: Int

    enum CodingKeys: String, CodingKey {
        case id
        case fileId = "file_id"
        case redactionType = "redaction_type"
        case bboxX = "bbox_x"
        case bboxY = "bbox_y"
        case bboxWidth = "bbox_width"
        case bboxHeight = "bbox_height"
        case pageNumber = "page_number"
        case createdBy = "created_by"
        case createdAt = "created_at"
    }

    var boundingBox: CGRect? {
        guard let x = bboxX, let y = bboxY, let w = bboxWidth, let h = bboxHeight else {
            return nil
        }
        return CGRect(x: x, y: y, width: w, height: h)
    }
}

struct CreateDetectionBody: Codable {
    let detectionType: String
    let bboxX: Double?
    let bboxY: Double?
    let bboxWidth: Double?
    let bboxHeight: Double?
    let pageNumber: Int?
    let textStart: Int?
    let textEnd: Int?
    let textContent: String?
    let confidence: Double?

    enum CodingKeys: String, CodingKey {
        case detectionType = "detection_type"
        case bboxX = "bbox_x"
        case bboxY = "bbox_y"
        case bboxWidth = "bbox_width"
        case bboxHeight = "bbox_height"
        case pageNumber = "page_number"
        case textStart = "text_start"
        case textEnd = "text_end"
        case textContent = "text_content"
        case confidence
    }
}

struct CreateManualRedactionBody: Codable {
    let redactionType: String
    let bboxX: Double
    let bboxY: Double
    let bboxWidth: Double
    let bboxHeight: Double
    let pageNumber: Int?

    enum CodingKeys: String, CodingKey {
        case redactionType = "redaction_type"
        case bboxX = "bbox_x"
        case bboxY = "bbox_y"
        case bboxWidth = "bbox_width"
        case bboxHeight = "bbox_height"
        case pageNumber = "page_number"
    }
}
