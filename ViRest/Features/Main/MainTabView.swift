import SwiftUI
import UIKit

struct MainTabView: View {
    @StateObject private var mainCoordinator = MainCoordinator()
    @StateObject private var homeViewModel: HomeViewModel
    @StateObject private var checkInViewModel: CheckInViewModel
    @StateObject private var profileViewModel: ProfileViewModel

    private let onSignOut: () -> Void

    init(container: AppContainer, onSignOut: @escaping () -> Void) {
        _homeViewModel = StateObject(wrappedValue: HomeViewModel(
            userProfileRepository: container.userProfileRepository,
            planRepository: container.planRepository,
            checkInRepository: container.checkInRepository,
            healthService: container.healthService,
            recommendationEngine: container.recommendationEngine,
            notificationService: container.notificationService
        ))

        _checkInViewModel = StateObject(wrappedValue: CheckInViewModel(
            userProfileRepository: container.userProfileRepository,
            planRepository: container.planRepository,
            checkInRepository: container.checkInRepository,
            badgeRepository: container.badgeStateRepository,
            healthService: container.healthService,
            planAdjustmentService: container.planAdjustmentService,
            gamificationService: container.gamificationService,
            notificationService: container.notificationService
        ))

        _profileViewModel = StateObject(wrappedValue: ProfileViewModel(
            userProfileRepository: container.userProfileRepository,
            planRepository: container.planRepository,
            badgeRepository: container.badgeStateRepository
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

            CheckInView(viewModel: checkInViewModel)
                .tabItem {
                    Label("Check-In", systemImage: "checkmark.seal.fill")
                }
                .tag(MainCoordinator.Tab.checkIn)

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
