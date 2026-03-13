import Foundation
import Combine
import SwiftUI

@MainActor
final class AppCoordinator: ObservableObject {
    enum Route {
        case loading
        case auth
        case onboarding
        case main
    }

    @Published private(set) var route: Route = .loading

    private let container: AppContainer

    init(container: AppContainer) {
        self.container = container
    }

    func bootstrap() async {
        await container.authService.restoreSession()

        switch container.authService.authState {
        case .signedOut:
            route = .auth
        case .signedIn(let user):
            if let firestoreUser = try? await container.firestoreUserRepository.loadUser(userId: user.id),
               firestoreUser.sportPlan != nil {
                route = .main
            } else {
                route = .onboarding
            }
        }
    }

    func didAuthenticate() {
        // After sign-in, re-run the full async bootstrap check
        Task {
            switch container.authService.authState {
            case .signedOut:
                route = .auth
            case .signedIn(let user):
                if let firestoreUser = try? await container.firestoreUserRepository.loadUser(userId: user.id),
                   firestoreUser.sportPlan != nil {
                    route = .main
                } else {
                    route = .onboarding
                }
            }
        }
    }

    func didCompleteOnboarding() {
        route = .main
    }

    func signOut() {
        try? container.authService.signOut()
        route = .auth
    }
}
