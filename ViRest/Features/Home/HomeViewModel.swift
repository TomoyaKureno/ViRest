import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var profile: UserProfileInput?
    @Published var plan: WeeklyPlan?
    @Published var healthSnapshot: HealthSnapshot?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    private let userProfileRepository: UserProfileRepository
    private let planRepository: PlanRepository
    private let checkInRepository: CheckInRepository
    private let healthService: HealthDataProviding
    private let recommendationEngine: RecommendationProviding
    private let notificationService: NotificationScheduling

    init(
        userProfileRepository: UserProfileRepository,
        planRepository: PlanRepository,
        checkInRepository: CheckInRepository,
        healthService: HealthDataProviding,
        recommendationEngine: RecommendationProviding,
        notificationService: NotificationScheduling
    ) {
        self.userProfileRepository = userProfileRepository
        self.planRepository = planRepository
        self.checkInRepository = checkInRepository
        self.healthService = healthService
        self.recommendationEngine = recommendationEngine
        self.notificationService = notificationService
    }

    func load() {
        Task {
            await loadInternal(regenerateIfNeeded: true)
        }
    }

    func regenerateNow() {
        Task {
            do {
                try await regeneratePlan(forceReason: "Plan regenerated using latest profile and health data.")
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func loadInternal(regenerateIfNeeded: Bool) async {
        isLoading = true
        errorMessage = nil

        do {
            guard let profile = try userProfileRepository.loadProfile() else {
                throw AppError.invalidState("Profile is missing. Please complete onboarding again.")
            }

            self.profile = profile
            self.healthSnapshot = await healthService.fetchLatestSnapshot(profile: profile)
            self.plan = try planRepository.loadCurrentPlan()

            if regenerateIfNeeded {
                try await maybeRecalibrate(profile: profile)
            }

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func maybeRecalibrate(profile: UserProfileInput) async throws {
        guard let currentPlan = plan else {
            try await regeneratePlan(forceReason: "No active plan found. Generated a new plan.")
            return
        }

        let now = Date()
        let weekDiff = Calendar.current.dateComponents([.day], from: currentPlan.generatedAt, to: now).day ?? 0
        let allCheckIns = try checkInRepository.loadCheckIns()
        let weekStart = now.startOfWeek()
        let weeklyCheckIns = allCheckIns.filter { $0.checkInDate >= weekStart }
        let adherence = currentPlan.sessions.isEmpty ? 0 : Double(weeklyCheckIns.count) / Double(currentPlan.sessions.count)

        var shouldRebuild = false
        var reason = ""

        if weekDiff >= 7 {
            shouldRebuild = true
            reason = "Weekly recalibration applied with latest data."
        } else if adherence < 0.4 {
            shouldRebuild = true
            reason = "Recalibrated because adherence was below 40%."
        } else if let rhr = healthSnapshot?.restingHeartRate, rhr >= 85 {
            shouldRebuild = true
            reason = "Recalibrated to safer plan due to elevated resting HR trend."
        }

        if shouldRebuild {
            try await regeneratePlan(forceReason: reason)
        }
    }

    private func regeneratePlan(forceReason: String) async throws {
        guard let profile else {
            throw AppError.invalidState("Profile must be loaded before plan regeneration.")
        }

        let goal = try planRepository.loadGoal() ?? .threeTimesPerWeek
        let snapshot = await healthService.fetchLatestSnapshot(profile: profile)

        let request = RecommendationRequest(
            userProfile: profile,
            healthSnapshot: snapshot,
            goalFrequency: goal,
            weekStartDate: Date()
        )

        let result = recommendationEngine.recommend(request: request)
        try planRepository.saveCurrentPlan(result.weeklyPlan)
        notificationService.schedulePlanReminders(for: result.weeklyPlan)

        self.healthSnapshot = snapshot
        self.plan = result.weeklyPlan
        self.infoMessage = forceReason
    }
}
