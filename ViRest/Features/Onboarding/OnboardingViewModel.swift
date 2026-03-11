import Foundation
import Combine

@MainActor
final class OnboardingViewModel: ObservableObject {
    enum HealthImportState: Equatable {
        case idle
        case requestingConsent
        case imported
        case noData
        case denied
    }

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

    @Published var enjoyableActivities: Set<ActivityType> = []
    @Published var intensityPreference: IntensityPreference = .light
    @Published var socialPreference: SocialPreference = .either
    @Published var consistency: ConsistencyLevel = .somewhatConsistent

    @Published var targetRestingHeartRateRange: RestingHeartRateRange = .from60To70
    @Published var weeklyGoal: WeeklyGoalFrequency = .threeTimesPerWeek

    @Published var acceptedDisclaimer = false

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var importedHealthSnapshot: HealthSnapshot?
    @Published private(set) var healthImportState: HealthImportState = .idle

    private let userProfileRepository: UserProfileRepository
    private let planRepository: PlanRepository
    private let healthService: HealthDataProviding
    private let recommendationEngine: RecommendationProviding
    private let notificationService: NotificationScheduling
    private let onCompleted: () -> Void
    private var didAttemptAutoImport = false

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

    func autoImportHealthDataIfNeeded() {
        guard !didAttemptAutoImport else { return }
        didAttemptAutoImport = true
        importHealthData()
    }

    func importHealthData() {
        Task {
            isLoading = true
            errorMessage = nil
            healthImportState = .requestingConsent

            let granted = await healthService.requestAuthorization()
            if !granted {
                await MainActor.run {
                    self.healthImportState = .denied
                    self.errorMessage = "Health access denied. You can enable permissions from iOS Settings > Health > Data Access."
                    self.isLoading = false
                }
                return
            }

            let snapshot = await healthService.fetchLatestSnapshot(profile: nil)
            await MainActor.run {
                if self.containsImportedHealthMetrics(snapshot) {
                    self.importedHealthSnapshot = snapshot
                    self.healthImportState = .imported
                    if let age = snapshot.ageYears {
                        self.ageText = String(age)
                    }
                    if let biologicalGender = snapshot.biologicalGender {
                        self.gender = biologicalGender
                    }
                    if let height = snapshot.heightCm {
                        self.heightCmText = String(format: "%.0f", height)
                    }
                    if let weight = snapshot.weightKg {
                        self.weightKgText = String(format: "%.1f", weight)
                    }
                    if let rhr = snapshot.restingHeartRate {
                        self.restingHeartRateRange = Self.range(from: rhr)
                    }
                } else {
                    self.healthImportState = .noData
                    self.errorMessage = "No Health data available yet. If Apple Watch has data, make sure Health sync is complete."
                }
                self.isLoading = false
            }
        }
    }

    func toggleHealthCondition(_ condition: HealthCondition) {
        if condition == .none {
            healthConditions = [.none]
            return
        }

        if healthConditions.contains(condition) {
            healthConditions.remove(condition)
        } else {
            healthConditions.insert(condition)
        }
        healthConditions.remove(.none)

        if healthConditions.isEmpty {
            healthConditions = [.none]
        }
    }

    func toggleEquipment(_ equipment: Equipment) {
        if equipment == .none {
            equipments = [.none]
            return
        }

        if equipments.contains(equipment) {
            equipments.remove(equipment)
        } else {
            equipments.insert(equipment)
        }
        equipments.remove(.none)

        if equipments.isEmpty {
            equipments = [.none]
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

        normalizeSelections()

        guard validateMandatoryInputs() else {
            isLoading = false
            return
        }

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
        let resolvedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "ViRest User" : fullName
        return UserProfileInput(
            fullName: resolvedName,
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
    }

    private func validateMandatoryInputs() -> Bool {
        guard let height = Double(heightCmText), height > 0 else {
            errorMessage = "Height is required."
            return false
        }

        guard let weight = Double(weightKgText), weight > 0 else {
            errorMessage = "Weight is required."
            return false
        }

        guard restingHeartRateRange != .unknown else {
            errorMessage = "Current resting heart rate is required."
            return false
        }

        if healthConditions.isEmpty {
            errorMessage = "Health condition is required."
            return false
        }

        if equipments.isEmpty {
            errorMessage = "At least one equipment option is required."
            return false
        }

        guard targetRestingHeartRateRange != .unknown, targetRestingHeartRateRange != .above90 else {
            errorMessage = "Target resting heart rate is required."
            return false
        }

        guard acceptedDisclaimer else {
            errorMessage = "Please accept the medical disclaimer before generating your plan."
            return false
        }

        return true
    }

    private func containsImportedHealthMetrics(_ snapshot: HealthSnapshot) -> Bool {
        snapshot.ageYears != nil ||
        snapshot.biologicalGender != nil ||
        snapshot.stepCount != nil ||
        snapshot.activeEnergyKCal != nil ||
        snapshot.heightCm != nil ||
        snapshot.weightKg != nil ||
        snapshot.restingHeartRate != nil ||
        snapshot.walkingHeartRateAverage != nil ||
        snapshot.peakHeartRate != nil ||
        snapshot.heartRateRecovery != nil ||
        snapshot.vo2Max != nil
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
