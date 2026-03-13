import SwiftUI
import UIKit

struct MainTabView: View {
    @StateObject private var mainCoordinator = MainCoordinator()
    @StateObject private var homeViewModel: HomeViewModel
    @StateObject private var profileViewModel: ProfileViewModel

    private let onSignOut: () -> Void

    init(container: AppContainer, onSignOut: @escaping () -> Void) {
        _homeViewModel = StateObject(wrappedValue: HomeViewModel(
            firestoreUserRepository: container.firestoreUserRepository,
            authService: container.authService,
            notificationService: container.notificationService,
            gamificationService: container.gamificationService,
            badgeRepository: container.badgeStateRepository,
            planAdjustmentService: container.planAdjustmentService
        ))

        _profileViewModel = StateObject(wrappedValue: ProfileViewModel(
            userProfileRepository: container.userProfileRepository,
            planRepository: container.planRepository,
            badgeRepository: container.badgeStateRepository,
            firestoreUserRepository: container.firestoreUserRepository,
            authService: container.authService
        ))

        self.onSignOut = onSignOut
        Self.configureTabBarAppearance()
    }

    var body: some View {
        TabView(selection: $mainCoordinator.selectedTab) {
            HomeView(viewModel: homeViewModel)
                .tabItem {
                    Label("Plan", systemImage: "heart.text.square.fill")
                }
                .tag(MainCoordinator.Tab.home)

            ProfileView(viewModel: profileViewModel, onSignOut: onSignOut)
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle.fill")
                }
                .tag(MainCoordinator.Tab.profile)
        }
        .tint(AppPalette.accent)
    }

    private static func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.richBlack).withAlphaComponent(0.95)

        let normal = appearance.stackedLayoutAppearance.normal
        normal.iconColor = UIColor(AppPalette.textSecondary)
        normal.titleTextAttributes = [
            .foregroundColor: UIColor(AppPalette.textSecondary),
            .font: UIFont(name: "AvenirNext-Medium", size: 11) ?? UIFont.systemFont(ofSize: 11, weight: .medium)
        ]

        let selected = appearance.stackedLayoutAppearance.selected
        selected.iconColor = UIColor(AppPalette.accent)
        selected.titleTextAttributes = [
            .foregroundColor: UIColor(AppPalette.accent),
            .font: UIFont(name: "AvenirNext-DemiBold", size: 11) ?? UIFont.systemFont(ofSize: 11, weight: .semibold)
        ]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}

@MainActor
private struct MainTabPreviewHost: View {
    private let container = PreviewSupport.makeSeededContainer()

    var body: some View {
        MainTabView(container: container, onSignOut: { })
    }
}

#Preview("Main Tab") {
    MainTabPreviewHost()
}
