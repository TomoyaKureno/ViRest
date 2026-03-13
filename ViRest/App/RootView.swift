import SwiftUI

struct RootView: View {
    @StateObject private var appCoordinator: AppCoordinator
    @StateObject private var authCoordinator = AuthCoordinator()
    @StateObject private var onboardingCoordinator = OnboardingCoordinator()

    private let container: AppContainer

    @StateObject private var authViewModel: AuthViewModel
    @StateObject private var onboardingViewModel: OnboardingViewModel

    init(container: AppContainer) {
        self.container = container

        let appCoordinator = AppCoordinator(container: container)
        _appCoordinator = StateObject(wrappedValue: appCoordinator)

        _authViewModel = StateObject(wrappedValue: AuthViewModel(
            authService: container.authService,
            onAuthenticated: {
                appCoordinator.didAuthenticate()
            }
        ))

        _onboardingViewModel = StateObject(wrappedValue: OnboardingViewModel(
            userProfileRepository: container.userProfileRepository,
            planRepository: container.planRepository,
            healthService: container.healthService,
            recommendationEngine: container.recommendationEngine,
            notificationService: container.notificationService,
            onCompleted: {
                appCoordinator.didCompleteOnboarding()
            }
        ))
    }

    var body: some View {
        Group {
            switch appCoordinator.route {
            case .loading:
                ZStack {
                    AppGradientBackground()
                    ProgressView("Preparing ViRest...")
                        .tint(.white)
                        .foregroundStyle(.white)
                }
            case .auth:
                NavigationStack(path: $authCoordinator.path) {
                    AuthView(viewModel: authViewModel)
                }
            case .onboarding:
                NavigationStack(path: $onboardingCoordinator.path) {
                    OnboardingView(
                        viewModel: onboardingViewModel,
                        onExitFromFirstQuestion: {
                            appCoordinator.signOut()
                        }
                    )
                }
            case .main:
                MainTabView(container: container) {
                    appCoordinator.signOut()
                }
            }
        }
        .task {
            await appCoordinator.bootstrap()
        }
    }
}

@MainActor
private struct RootPreviewHost: View {
    private let container = PreviewSupport.makeSeededContainer()

    var body: some View {
        RootView(container: container)
    }
}

#Preview("Root") {
    RootPreviewHost()
}
