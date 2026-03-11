import Foundation
import Combine

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var profile: UserProfileInput?
    @Published var badgeState: BadgeState = .default
    @Published var weeklyGoal: WeeklyGoalFrequency = .threeTimesPerWeek
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    private let userProfileRepository: UserProfileRepository
    private let planRepository: PlanRepository
    private let badgeRepository: BadgeStateRepository

    init(
        userProfileRepository: UserProfileRepository,
        planRepository: PlanRepository,
        badgeRepository: BadgeStateRepository
    ) {
        self.userProfileRepository = userProfileRepository
        self.planRepository = planRepository
        self.badgeRepository = badgeRepository
    }

    func load() {
        Task {
            await loadInternal()
        }
    }

    func updateGoal() {
        Task {
            await updateGoalInternal()
        }
    }

    private func loadInternal() async {
        isLoading = true
        errorMessage = nil

        do {
            profile = try userProfileRepository.loadProfile()
            weeklyGoal = try planRepository.loadGoal() ?? .threeTimesPerWeek
            badgeState = try badgeRepository.loadState()
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func updateGoalInternal() async {
        // Goal is intentionally locked after onboarding in current product policy.
        infoMessage = "Weekly goal is locked after initial setup."
    }
}
