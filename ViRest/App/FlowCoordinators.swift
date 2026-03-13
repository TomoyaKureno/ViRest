import Foundation
import Combine
import SwiftUI

@MainActor
final class AuthCoordinator: ObservableObject {
    @Published var path = NavigationPath()
}

@MainActor
final class OnboardingCoordinator: ObservableObject {
    @Published var path = NavigationPath()
}

@MainActor
final class MainCoordinator: ObservableObject {
    enum Tab: Hashable {
        case home
        case profile
    }

    @Published var selectedTab: Tab = .home
}
