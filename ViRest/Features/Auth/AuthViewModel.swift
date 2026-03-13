import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let authService: AuthProviding
    private let onAuthenticated: () -> Void
    
    private let firestoreUserRepository: FirestoreUserRepository

    init(
        authService: AuthProviding,
        onAuthenticated: @escaping () -> Void,
        firestoreUserRepository: FirestoreUserRepository
    ) {
        self.authService = authService
        self.onAuthenticated = onAuthenticated
        self.firestoreUserRepository = firestoreUserRepository
    }


    private func runAuth(action: @escaping () async throws -> AuthUser) {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let authUser = try await action()
                try await firestoreUserRepository.ensureUserExists(authUser: authUser)
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

    func signInWithApple() {
        runAuth { [authService] in
            try await authService.signInWithApple()
        }
    }

    func signInWithGoogle() {
        runAuth { [authService] in
            try await authService.signInWithGoogle()
        }
    }

    // Additional test entry points to avoid changing existing buttons.
    func testSignInWithApple() {
        signInWithApple()
    }

    func testSignInWithGoogle() {
        signInWithGoogle()
    }
    
    // Update RootView to pass firestoreUserRepository:
    // _authViewModel = StateObject(wrappedValue: AuthViewModel(
    //     authService: container.authService,
    //     firestoreUserRepository: container.firestoreUserRepository,
    //     onAuthenticated: { appCoordinator.didAuthenticate() }
    // ))

}

