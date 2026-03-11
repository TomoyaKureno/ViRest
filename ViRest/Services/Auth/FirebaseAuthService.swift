import Foundation
import Combine

@MainActor
final class FirebaseAuthService: AuthProviding, ObservableObject {
    private enum Keys {
        static let savedAuthUser = "virest.saved_auth_user"
    }

    @Published private(set) var authState: AppAuthState = .signedOut

    private let userDefaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func restoreSession() async {
        guard let data = userDefaults.data(forKey: Keys.savedAuthUser),
              let user = try? decoder.decode(AuthUser.self, from: data) else {
            authState = .signedOut
            return
        }

        authState = .signedIn(user)
    }

    func signInWithApple() async throws -> AuthUser {
        // Placeholder implementation. Replace with Firebase + Sign in with Apple SDK flow.
        let user = AuthUser(
            id: UUID().uuidString,
            email: "apple.user@virest.app",
            displayName: "Apple User",
            provider: .apple
        )

        try persist(user)
        authState = .signedIn(user)
        return user
    }

    func signInWithGoogle() async throws -> AuthUser {
        // Placeholder implementation. Replace with Firebase + Google Sign-In SDK flow.
        let user = AuthUser(
            id: UUID().uuidString,
            email: "google.user@virest.app",
            displayName: "Google User",
            provider: .google
        )

        try persist(user)
        authState = .signedIn(user)
        return user
    }

    func signOut() throws {
        userDefaults.removeObject(forKey: Keys.savedAuthUser)
        authState = .signedOut
    }

    private func persist(_ user: AuthUser) throws {
        do {
            let data = try encoder.encode(user)
            userDefaults.set(data, forKey: Keys.savedAuthUser)
        } catch {
            throw AppError.auth("Failed to persist auth user: \(error.localizedDescription)")
        }
    }
}
