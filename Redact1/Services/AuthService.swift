import Foundation
import SwiftUI

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var error: String?

    private let tokenKey = "redact1_auth_token"
    private let userKey = "redact1_user"

    private init() {
        loadStoredAuth()
    }

    private func loadStoredAuth() {
        if let token = UserDefaults.standard.string(forKey: tokenKey),
           let userData = UserDefaults.standard.data(forKey: userKey),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            Task {
                await APIService.shared.setToken(token)
                self.currentUser = user
                self.isAuthenticated = true

                // Verify token is still valid
                do {
                    let freshUser = try await APIService.shared.getCurrentUser()
                    self.currentUser = freshUser
                } catch {
                    // Token invalid, clear stored auth
                    await self.logout()
                }
            }
        }
    }

    func login(email: String, password: String) async {
        isLoading = true
        error = nil

        do {
            let response = try await APIService.shared.login(email: email, password: password)

            // Store credentials
            UserDefaults.standard.set(response.token, forKey: tokenKey)
            if let userData = try? JSONEncoder().encode(response.user) {
                UserDefaults.standard.set(userData, forKey: userKey)
            }

            currentUser = response.user
            isAuthenticated = true
        } catch let apiError as APIError {
            error = apiError.localizedDescription
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }

    func logout() async {
        do {
            try await APIService.shared.logout()
        } catch {
            // Ignore logout errors
        }

        await APIService.shared.setToken(nil)
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: userKey)

        currentUser = nil
        isAuthenticated = false
    }
}
