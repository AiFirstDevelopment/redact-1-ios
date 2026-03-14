import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case notFound
    case serverError(String)
    case decodingError(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response from server"
        case .unauthorized: return "Unauthorized - please log in again"
        case .notFound: return "Resource not found"
        case .serverError(let message): return message
        case .decodingError(let error): return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error): return "Network error: \(error.localizedDescription)"
        }
    }
}

actor APIService {
    static let shared = APIService()

    private let baseURL = "https://redact-1-worker.joelstevick.workers.dev"
    private var token: String?

    private init() {}

    func setToken(_ token: String?) {
        self.token = token
    }

    private func makeRequest(_ path: String, method: String = "GET", body: Data? = nil, contentType: String = "application/json") async throws -> Data {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = body {
            request.httpBody = body
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            switch httpResponse.statusCode {
            case 200...299:
                return data
            case 401:
                throw APIError.unauthorized
            case 404:
                throw APIError.notFound
            default:
                if let errorResponse = try? JSONDecoder().decode([String: String].self, from: data),
                   let message = errorResponse["error"] {
                    throw APIError.serverError(message)
                }
                throw APIError.serverError("Server returned status \(httpResponse.statusCode)")
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    // MARK: - Auth

    func login(identifier: String, password: String, identifierType: String) async throws -> LoginResponse {
        struct LoginBody: Codable {
            let identifier: String
            let password: String
            let identifierType: String
        }
        let body = try JSONEncoder().encode(LoginBody(identifier: identifier, password: password, identifierType: identifierType))
        let data = try await makeRequest("/api/auth/login", method: "POST", body: body)
        let response = try JSONDecoder().decode(LoginResponse.self, from: data)
        self.token = response.token
        return response
    }

    // Convenience for email login
    func login(email: String, password: String) async throws -> LoginResponse {
        return try await login(identifier: email, password: password, identifierType: "email")
    }

    func logout() async throws {
        _ = try await makeRequest("/api/auth/logout", method: "POST")
        self.token = nil
    }

    func getCurrentUser() async throws -> User {
        let data = try await makeRequest("/api/auth/me")
        let response = try JSONDecoder().decode([String: User].self, from: data)
        guard let user = response["user"] else {
            throw APIError.invalidResponse
        }
        return user
    }

    // MARK: - Users

    func listUsers() async throws -> [User] {
        let data = try await makeRequest("/api/users")
        let response = try JSONDecoder().decode([String: [User]].self, from: data)
        return response["users"] ?? []
    }

    func createUser(name: String, email: String, password: String) async throws -> User {
        struct CreateUserBody: Codable {
            let name: String
            let email: String
            let password: String
        }
        let body = try JSONEncoder().encode(CreateUserBody(name: name, email: email, password: password))
        let data = try await makeRequest("/api/users", method: "POST", body: body)
        let response = try JSONDecoder().decode([String: User].self, from: data)
        guard let user = response["user"] else {
            throw APIError.invalidResponse
        }
        return user
    }

    // MARK: - Requests

    func listRequests(status: RequestStatus? = nil, search: String? = nil) async throws -> [RecordsRequest] {
        var path = "/api/requests"
        var queryItems: [String] = []

        if let status = status {
            queryItems.append("status=\(status.rawValue)")
        }
        if let search = search, !search.isEmpty {
            queryItems.append("search=\(search.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? search)")
        }
        if !queryItems.isEmpty {
            path += "?" + queryItems.joined(separator: "&")
        }

        let data = try await makeRequest(path)
        let response = try JSONDecoder().decode([String: [RecordsRequest]].self, from: data)
        return response["requests"] ?? []
    }

    func getRequest(_ id: String) async throws -> RecordsRequest {
        let data = try await makeRequest("/api/requests/\(id)")
        let response = try JSONDecoder().decode([String: RecordsRequest].self, from: data)
        guard let request = response["request"] else {
            throw APIError.invalidResponse
        }
        return request
    }

    func createRequest(_ body: CreateRequestBody) async throws -> RecordsRequest {
        let requestBody = try JSONEncoder().encode(body)
        let data = try await makeRequest("/api/requests", method: "POST", body: requestBody)
        let response = try JSONDecoder().decode([String: RecordsRequest].self, from: data)
        guard let request = response["request"] else {
            throw APIError.invalidResponse
        }
        return request
    }

    func updateRequest(_ id: String, body: UpdateRequestBody) async throws -> RecordsRequest {
        let requestBody = try JSONEncoder().encode(body)
        let data = try await makeRequest("/api/requests/\(id)", method: "PUT", body: requestBody)
        let response = try JSONDecoder().decode([String: RecordsRequest].self, from: data)
        guard let request = response["request"] else {
            throw APIError.invalidResponse
        }
        return request
    }

    func deleteRequest(_ id: String) async throws {
        _ = try await makeRequest("/api/requests/\(id)", method: "DELETE")
    }

    // MARK: - Files

    func listFiles(requestId: String) async throws -> [EvidenceFile] {
        let data = try await makeRequest("/api/requests/\(requestId)/files")
        let response = try JSONDecoder().decode([String: [EvidenceFile]].self, from: data)
        return response["files"] ?? []
    }

    func uploadFile(requestId: String, fileData: Data, filename: String, mimeType: String) async throws -> EvidenceFile {
        guard let url = URL(string: "\(baseURL)/api/requests/\(requestId)/files") else {
            throw APIError.invalidURL
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
            throw APIError.invalidResponse
        }

        let responseData = try JSONDecoder().decode([String: EvidenceFile].self, from: data)
        guard let file = responseData["file"] else {
            throw APIError.invalidResponse
        }
        return file
    }

    func getFileOriginal(_ id: String) async throws -> Data {
        return try await makeRequest("/api/files/\(id)/original")
    }

    func getFileRedacted(_ id: String) async throws -> Data {
        return try await makeRequest("/api/files/\(id)/redacted")
    }

    func deleteFile(_ id: String) async throws {
        _ = try await makeRequest("/api/files/\(id)", method: "DELETE")
    }

    // MARK: - Detections

    func listDetections(fileId: String) async throws -> (detections: [Detection], manualRedactions: [ManualRedaction]) {
        let data = try await makeRequest("/api/files/\(fileId)/detections")
        struct Response: Codable {
            let detections: [Detection]
            let manual_redactions: [ManualRedaction]
        }
        let response = try JSONDecoder().decode(Response.self, from: data)
        return (response.detections, response.manual_redactions)
    }

    func createDetections(fileId: String, detections: [CreateDetectionBody]) async throws -> [Detection] {
        struct RequestBody: Codable {
            let detections: [CreateDetectionBody]
        }
        let body = try JSONEncoder().encode(RequestBody(detections: detections))
        let data = try await makeRequest("/api/files/\(fileId)/detections", method: "POST", body: body)
        let response = try JSONDecoder().decode([String: [Detection]].self, from: data)
        return response["detections"] ?? []
    }

    func updateDetection(_ id: String, status: DetectionStatus) async throws -> Detection {
        struct RequestBody: Codable {
            let status: String
        }
        let body = try JSONEncoder().encode(RequestBody(status: status.rawValue))
        let data = try await makeRequest("/api/detections/\(id)", method: "PUT", body: body)
        let response = try JSONDecoder().decode([String: Detection].self, from: data)
        guard let detection = response["detection"] else {
            throw APIError.invalidResponse
        }
        return detection
    }

    func createManualRedaction(fileId: String, body: CreateManualRedactionBody) async throws -> ManualRedaction {
        let requestBody = try JSONEncoder().encode(body)
        let data = try await makeRequest("/api/files/\(fileId)/manual-redactions", method: "POST", body: requestBody)
        let response = try JSONDecoder().decode([String: ManualRedaction].self, from: data)
        guard let redaction = response["manual_redaction"] else {
            throw APIError.invalidResponse
        }
        return redaction
    }

    func deleteManualRedaction(_ id: String) async throws {
        _ = try await makeRequest("/api/manual-redactions/\(id)", method: "DELETE")
    }

    // MARK: - Exports

    func createExport(requestId: String) async throws -> (exportId: String, files: [EvidenceFile]) {
        let data = try await makeRequest("/api/requests/\(requestId)/export", method: "POST")
        struct Response: Codable {
            struct ExportInfo: Codable {
                let id: String
            }
            struct FileInfo: Codable {
                let id: String
                let filename: String
                let file_type: String
            }
            let `export`: ExportInfo
            let files: [FileInfo]
        }
        let response = try JSONDecoder().decode(Response.self, from: data)

        // Fetch full file objects
        var files: [EvidenceFile] = []
        for fileInfo in response.files {
            let fileData = try await makeRequest("/api/files/\(fileInfo.id)")
            let fileResponse = try JSONDecoder().decode([String: EvidenceFile].self, from: fileData)
            if let file = fileResponse["file"] {
                files.append(file)
            }
        }

        return (response.export.id, files)
    }

    func uploadRedactedFile(_ fileId: String, data: Data, mimeType: String) async throws {
        guard let url = URL(string: "\(baseURL)/api/files/\(fileId)/redacted") else {
            throw APIError.invalidURL
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"redacted\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse
        }
    }
}
