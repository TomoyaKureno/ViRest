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
        route = resolveRoute()
    }

    func didAuthenticate() {
        route = resolveRoute()
    }

    func didCompleteOnboarding() {
        route = .main
    }

    func signOut() {
        try? container.authService.signOut()
        route = .auth
    }

    private func resolveRoute() -> Route {
        switch container.authService.authState {
        case .signedOut:
            return .auth
        case .signedIn:
            let profile = try? container.userProfileRepository.loadProfile()
            return (profile == nil) ? .onboarding : .main
        }
    }
}
