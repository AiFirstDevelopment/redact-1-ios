import Foundation

enum UserRole: String, Codable, CaseIterable {
    case clerk
    case supervisor

    var displayName: String {
        switch self {
        case .clerk: return "Clerk"
        case .supervisor: return "Supervisor"
        }
    }
}

struct User: Codable, Identifiable {
    let id: String
    let email: String
    let name: String
    let role: UserRole
    let createdAt: Int
    let updatedAt: Int

    enum CodingKeys: String, CodingKey {
        case id, email, name, role
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        name = try container.decode(String.self, forKey: .name)
        role = try container.decodeIfPresent(UserRole.self, forKey: .role) ?? .clerk
        createdAt = try container.decode(Int.self, forKey: .createdAt)
        updatedAt = try container.decode(Int.self, forKey: .updatedAt)
    }

    init(id: String, email: String, name: String, role: UserRole = .clerk, createdAt: Int, updatedAt: Int) {
        self.id = id
        self.email = email
        self.name = name
        self.role = role
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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
