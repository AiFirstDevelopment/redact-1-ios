import Foundation

struct User: Codable, Identifiable {
    let id: String
    let email: String
    let name: String
    let createdAt: Int
    let updatedAt: Int

    enum CodingKeys: String, CodingKey {
        case id, email, name
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct LoginRequest: Codable {
    let email: String
    let password: String
}

struct LoginResponse: Codable {
    let token: String
    let user: User
}

struct AuthState {
    var token: String?
    var user: User?

    var isAuthenticated: Bool {
        token != nil && user != nil
    }
}
