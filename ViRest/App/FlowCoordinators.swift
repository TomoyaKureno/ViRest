import Foundation
import Combine
import SwiftUI

@MainActor
final class AuthCoordinator: ObservableObject {
    enum Destination: Hashable {
        case onboardingRegister
        case register
    }

    @Published var path: [Destination] = []
}

@MainActor
final class OnboardingCoordinator: ObservableObject {
    @Published var path = NavigationPath()
}

@MainActor
final class MainCoordinator: ObservableObject {
    enum Tab: Hashable {
        case home
        case rewards
        case profile
    }

    @Published var selectedTab: Tab = .home
}
