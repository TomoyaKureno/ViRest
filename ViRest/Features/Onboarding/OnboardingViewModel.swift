import Foundation
import Combine

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var fullName: String = ""
    @Published var ageText: String = ""
    @Published var gender: Gender?

    @Published var heightCmText: String = ""
    @Published var weightKgText: String = ""
    @Published var restingHeartRateRange: RestingHeartRateRange = .unknown

    @Published var healthConditions: Set<HealthCondition> = [.none]
    @Published var injuryLimitation: InjuryLimitation = .noLimitation

    @Published var sessionDuration: SessionDurationOption = .twentyToThirty
    @Published var daysPerWeek: DaysPerWeekAvailability = .three
    @Published var preferredTime: PreferredTime = .noPreference

    @Published var environment: SportEnvironment = .both
    @Published var equipments: Set<Equipment> = [.none]

    @Published var enjoyableActivities: Set<ActivityType> = [.walking]
    @Published var intensityPreference: IntensityPreference = .light
    @Published var socialPreference: SocialPreference = .either
    @Published var consistency: ConsistencyLevel = .somewhatConsistent

    @Published var targetRestingHeartRateRange: RestingHeartRateRange = .from60To70
    @Published var weeklyGoal: WeeklyGoalFrequency = .threeTimesPerWeek

    @Published var acceptedDisclaimer = false

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var importedHealthSnapshot: HealthSnapshot?

    private let userProfileRepository: UserProfileRepository
    private let planRepository: PlanRepository
    private let healthService: HealthDataProviding
    private let recommendationEngine: RecommendationProviding
    private let notificationService: NotificationScheduling
    private let onCompleted: () -> Void

    init(
        userProfileRepository: UserProfileRepository,
        planRepository: PlanRepository,
        healthService: HealthDataProviding,
        recommendationEngine: RecommendationProviding,
        notificationService: NotificationScheduling,
        onCompleted: @escaping () -> Void
    ) {
        self.userProfileRepository = userProfileRepository
        self.planRepository = planRepository
        self.healthService = healthService
        self.recommendationEngine = recommendationEngine
        self.notificationService = notificationService
        self.onCompleted = onCompleted
    }

    func importHealthData() {
        Task {
            isLoading = true
            errorMessage = nil

            let granted = await healthService.requestAuthorization()
            guard granted else {
                await MainActor.run {
                    self.errorMessage = "Health access denied. We'll continue with manual input."
                    self.isLoading = false
                }
                return
            }

            let snapshot = await healthService.fetchLatestSnapshot(profile: nil)
            await MainActor.run {
                self.importedHealthSnapshot = snapshot
                if let height = snapshot.heightCm {
                    self.heightCmText = String(format: "%.0f", height)
                }
                if let weight = snapshot.weightKg {
                    self.weightKgText = String(format: "%.1f", weight)
                }
                if let rhr = snapshot.restingHeartRate {
                    self.restingHeartRateRange = Self.range(from: rhr)
                }
                self.isLoading = false
            }
        }
    }

    func submit() {
        Task {
            await submitInternal()
        }
    }

    private func submitInternal() async {
        isLoading = true
        errorMessage = nil

        guard acceptedDisclaimer else {
            errorMessage = "Please accept the medical disclaimer before generating your plan."
            isLoading = false
            return
        }

        guard !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please fill in your name."
            isLoading = false
            return
        }

        normalizeSelections()

        let profile = buildProfile()

        do {
            try userProfileRepository.saveProfile(profile)
            try planRepository.saveGoal(weeklyGoal)

            let snapshot = await healthService.fetchLatestSnapshot(profile: profile)
            importedHealthSnapshot = snapshot

            let request = RecommendationRequest(
                userProfile: profile,
                healthSnapshot: snapshot,
                goalFrequency: weeklyGoal,
                weekStartDate: Date()
            )
            let result = recommendationEngine.recommend(request: request)
            try planRepository.saveCurrentPlan(result.weeklyPlan)

            _ = await notificationService.requestAuthorization()
            notificationService.schedulePlanReminders(for: result.weeklyPlan)

            isLoading = false
            onCompleted()
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func buildProfile() -> UserProfileInput {
        UserProfileInput(
            fullName: fullName,
            age: Int(ageText),
            gender: gender,
            heightCm: Double(heightCmText),
            weightKg: Double(weightKgText),
            restingHeartRateRange: restingHeartRateRange,
            healthConditions: normalizedHealthConditions(),
            injuryLimitation: injuryLimitation,
            sessionDuration: sessionDuration,
            daysPerWeek: daysPerWeek,
            preferredTime: preferredTime,
            environment: environment,
            equipments: normalizedEquipments(),
            enjoyableActivities: Array(enjoyableActivities),
            intensityPreference: intensityPreference,
            socialPreference: socialPreference,
            consistency: consistency,
            targetRestingHeartRateRange: targetRestingHeartRateRange,
            acceptedDisclaimer: acceptedDisclaimer,
            updatedAt: Date()
        )
    }

    private func normalizeSelections() {
        if healthConditions.contains(.none), healthConditions.count > 1 {
            healthConditions.remove(.none)
        }

        if healthConditions.isEmpty {
            healthConditions.insert(.none)
        }

        if equipments.contains(.none), equipments.count > 1 {
            equipments.remove(.none)
        }

        if equipments.isEmpty {
            equipments.insert(.none)
        }

        if enjoyableActivities.isEmpty {
            enjoyableActivities.insert(.walking)
        }
    }

    private func normalizedHealthConditions() -> [HealthCondition] {
        var list = Array(healthConditions)
        if list.contains(.none), list.count > 1 {
            list.removeAll { $0 == .none }
        }
        return list
    }

    private func normalizedEquipments() -> [Equipment] {
        var list = Array(equipments)
        if list.contains(.none), list.count > 1 {
            list.removeAll { $0 == .none }
        }
        return list
    }

    private static func range(from restingHeartRate: Double) -> RestingHeartRateRange {
        switch restingHeartRate {
        case ..<50:
            return .below50
        case 50..<60:
            return .from50To60
        case 60..<70:
            return .from60To70
        case 70..<81:
            return .from71To80
        case 81..<91:
            return .from81To90
        default:
            return .above90
        }
    }
}
