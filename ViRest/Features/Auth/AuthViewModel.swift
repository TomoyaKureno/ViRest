import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authService: AuthProviding
    private let onAuthenticated: () -> Void

    init(authService: AuthProviding, onAuthenticated: @escaping () -> Void) {
        self.authService = authService
        self.onAuthenticated = onAuthenticated
    }

    func signInWithApple() {
        runAuth { [authService] in
            _ = try await authService.signInWithApple()
        }
    }

    func signInWithGoogle() {
        runAuth { [authService] in
            _ = try await authService.signInWithGoogle()
        }
    }

    // Additional test entry points to avoid changing existing buttons.
    func testSignInWithApple() {
        signInWithApple()
    }

    func testSignInWithGoogle() {
        signInWithGoogle()
    }

    private func runAuth(action: @escaping () async throws -> Void) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await action()
                await MainActor.run {
                    self.isLoading = false
                    self.onAuthenticated()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
}

