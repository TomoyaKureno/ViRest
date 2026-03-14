import SwiftUI

struct RootView: View {
    @StateObject private var appCoordinator: AppCoordinator
    @StateObject private var authCoordinator: AuthCoordinator
    @StateObject private var onboardingCoordinator = OnboardingCoordinator()

    private let container: AppContainer

    @StateObject private var authViewModel: AuthViewModel
    @StateObject private var onboardingLoginViewModel: OnboardingViewModel
    @StateObject private var onboardingRegisterViewModel: OnboardingViewModel

    init(container: AppContainer) {
        self.container = container

        let appCoordinator = AppCoordinator(container: container)
        let authCoordinator = AuthCoordinator()

        let onboardingLoginViewModel = OnboardingViewModel(
            userProfileRepository: container.userProfileRepository,
            planRepository: container.planRepository,
            healthService: container.healthService,
            recommendationEngine: container.recommendationEngine,
            notificationService: container.notificationService,
            firestoreUserRepository: container.firestoreUserRepository,
            authService: container.authService,
            onCompleted: {
                appCoordinator.didCompleteOnboarding()
            }
        )

        let onboardingRegisterViewModel = OnboardingViewModel(
            userProfileRepository: container.userProfileRepository,
            planRepository: container.planRepository,
            healthService: container.healthService,
            recommendationEngine: container.recommendationEngine,
            notificationService: container.notificationService,
            firestoreUserRepository: container.firestoreUserRepository,
            authService: container.authService,
            onCompleted: {
                if authCoordinator.path.last != .register {
                    authCoordinator.path.append(.register)
                }
            }
        )

        let authViewModel = AuthViewModel(
            authService: container.authService,
            onAuthenticated: {
                Task {
                    await onboardingRegisterViewModel.finalizePendingGuestSubmissionIfNeeded()
                    appCoordinator.didAuthenticate()
                }
            },
            firestoreUserRepository: container.firestoreUserRepository
        )

        _appCoordinator = StateObject(wrappedValue: appCoordinator)
        _authCoordinator = StateObject(wrappedValue: authCoordinator)
        _authViewModel = StateObject(wrappedValue: authViewModel)
        _onboardingLoginViewModel = StateObject(wrappedValue: onboardingLoginViewModel)
        _onboardingRegisterViewModel = StateObject(wrappedValue: onboardingRegisterViewModel)
    }

    var body: some View {
        Group {
            switch appCoordinator.route {
            case .loading:
                ZStack {
                    ProgressView("Preparing ViRest...")
                        .tint(.white)
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.richBlack)
            case .login:
                NavigationStack(path: $authCoordinator.path) {
                    LoginView(
                        viewModel: authViewModel,
                        onStart: {
                            authCoordinator.path = [.onboardingRegister]
                        }
                    )
                    .navigationDestination(for: AuthCoordinator.Destination.self) { destination in
                        switch destination {
                        case .onboardingRegister:
                            OnboardingView(
                                viewModel: onboardingRegisterViewModel,
                                onExitFromFirstQuestion: {
                                    authCoordinator.path.removeAll()
                                }
                            )
                        case .register:
                            RegisterView(
                                viewModel: authViewModel,
                                onBack: {
                                    guard !authCoordinator.path.isEmpty else { return }
                                    authCoordinator.path.removeLast()
                                },
                                onBackToLogin: {
                                    authCoordinator.path.removeAll()
                                }
                            )
                        }
                    }
                }
            case .onboardingLogin:
                NavigationStack(path: $onboardingCoordinator.path) {
                    OnboardingView(
                        viewModel: onboardingLoginViewModel,
                        onExitFromFirstQuestion: {
                            appCoordinator.signOut()
                        }
                    )
                }
            case .main:
                MainTabView(container: container) {
                    appCoordinator.signOut()
                    authCoordinator.path.removeAll()
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
