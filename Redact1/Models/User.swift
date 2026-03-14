import Foundation

enum UserRole: String, Codable, CaseIterable {
    case officer
    case admin

    var displayName: String {
        switch self {
        case .officer: return "Officer"
        case .admin: return "Admin"
        }
    }
}

struct User: Codable, Identifiable {
    let id: String
    let email: String
    let name: String
    let badgeNumber: String?
    let role: UserRole
    let createdAt: Int
    let updatedAt: Int

    enum CodingKeys: String, CodingKey {
        case id, email, name, role
        case badgeNumber = "badge_number"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        name = try container.decode(String.self, forKey: .name)
        badgeNumber = try container.decodeIfPresent(String.self, forKey: .badgeNumber)
        role = try container.decodeIfPresent(UserRole.self, forKey: .role) ?? .officer
        createdAt = try container.decode(Int.self, forKey: .createdAt)
        updatedAt = try container.decode(Int.self, forKey: .updatedAt)
    }

    init(id: String, email: String, name: String, badgeNumber: String?, role: UserRole = .officer, createdAt: Int, updatedAt: Int) {
        self.id = id
        self.email = email
        self.name = name
        self.badgeNumber = badgeNumber
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
