import Foundation
import Combine

@MainActor
final class OnboardingViewModel: ObservableObject {
    private static let healthKitSynchronizedDefaultsKey = "onboarding.healthkit.synchronized"

    struct RecommendationSummary: Equatable {
        struct SportFactor: Equatable, Identifiable {
            let id = UUID()
            let sportName: String
            let compatibilityPercent: Int
            let hasProgression: Bool
            let weekOneFrequency: Int
            let weekTwoPlusFrequency: Int
            let weekOneSessionMinutes: Int
            let weekTwoPlusSessionMinutes: Int
            let cautions: [String]
        }

        let primaryActivityName: String
        let sports: [SportFactor]
    }

    enum HealthImportState: Equatable {
        case idle
        case requestingConsent
        case imported
        case noData
        case denied
    }

    
    private let firestoreUserRepository: FirestoreUserRepository
    private let authService: AuthProviding
    
    @Published var fullName: String = ""
    @Published var ageText: String = ""
    @Published var gender: Gender?

    @Published var questionnaireCurrentRHRBand: CurrentRHRBandQuestion = .from61To75
    @Published var questionnaireTargetRHRGoal: TargetRHRGoalQuestion = .from60To69

    @Published var heightCmText: String = ""
    @Published var weightKgText: String = ""

    @Published var healthConcerns: Set<HealthConcernOption> = [.none]

    @Published var sessionDuration: SessionDurationOption = .tenToTwenty
    @Published var daysPerWeek: DaysPerWeekAvailability = .twoToThree
    @Published var preferredTime: PreferredTime = .flexible

    @Published var environment: SportEnvironment = .both
    @Published var accessOptions: Set<ExerciseAccessOptionQuestion> = [.none]

    @Published var enjoyableActivities: Set<ActivityType> = []
    @Published var intensityPreference: IntensityPreference = .light
    @Published var socialPreference: SocialPreference = .either
    @Published var consistency: ConsistencyLevel = .somewhatConsistent
    @Published var cardioExperienceLevel: CardioExperienceLevel?

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var importedHealthSnapshot: HealthSnapshot?
    @Published var recommendationSummary: RecommendationSummary?
    @Published private(set) var healthImportState: HealthImportState = .idle
    @Published private(set) var isHealthKitSynchronized = false

    private let userProfileRepository: UserProfileRepository
    private let planRepository: PlanRepository
    private let healthService: HealthDataProviding
    private let recommendationEngine: RecommendationProviding
    private let notificationService: NotificationScheduling
    private let onCompleted: () -> Void
    private var didAttemptAutoImport = false
    private var pendingGuestProfile: UserProfileInput?
    private var pendingGuestSportPlan: FirestoreSportPlan?

    init(
        userProfileRepository: UserProfileRepository,
        planRepository: PlanRepository,
        healthService: HealthDataProviding,
        recommendationEngine: RecommendationProviding,
        notificationService: NotificationScheduling,
        firestoreUserRepository: FirestoreUserRepository,
        authService: AuthProviding,
        onCompleted: @escaping () -> Void
    ) {
        self.userProfileRepository = userProfileRepository
        self.planRepository = planRepository
        self.healthService = healthService
        self.recommendationEngine = recommendationEngine
        self.notificationService = notificationService
        self.firestoreUserRepository = firestoreUserRepository
        self.authService = authService
        self.onCompleted = onCompleted
        self.isHealthKitSynchronized = false
    }

    func autoImportHealthDataIfNeeded() {
        guard !didAttemptAutoImport else { return }
        didAttemptAutoImport = true
        importHealthData()
    }

    func resetForNewOnboarding() {
        fullName = ""
        ageText = ""
        gender = nil

        questionnaireCurrentRHRBand = .from61To75
        questionnaireTargetRHRGoal = .from60To69
        heightCmText = ""
        weightKgText = ""

        healthConcerns = [.none]
        sessionDuration = .twentyToThirty
        daysPerWeek = .threeToFour
        preferredTime = .flexible
        environment = .both
        accessOptions = [.none]
        enjoyableActivities = []
        intensityPreference = .light
        socialPreference = .either
        consistency = .somewhatConsistent
        cardioExperienceLevel = nil

        isLoading = false
        errorMessage = nil
        importedHealthSnapshot = nil
        recommendationSummary = nil
        healthImportState = .idle
        isHealthKitSynchronized = false
        pendingGuestProfile = nil
        pendingGuestSportPlan = nil
        didAttemptAutoImport = false
    }

    func prepareHealthDataOnEntry() async {
        healthImportState = .idle
        isHealthKitSynchronized = false

        if healthService.authorizationState == .authorized || hasPersistedHealthKitSyncState() {
            isHealthKitSynchronized = true
        }

        let snapshot = await healthService.fetchLatestSnapshot(profile: nil)
        guard containsImportedHealthMetrics(snapshot) else {
            return
        }

        applyImportedMetrics(from: snapshot)
    }

    func shouldPresentHealthKitPrompt() async -> Bool {
        await healthService.shouldPresentAuthorizationPrompt()
    }

    func importHealthData() {
        Task {
            isLoading = true
            errorMessage = nil
            healthImportState = .requestingConsent

            let granted: Bool
            if healthService.authorizationState == .authorized {
                granted = true
            } else {
                granted = await healthService.requestAuthorization()
            }
            if !granted {
                await MainActor.run {
                    self.healthImportState = .denied
                    self.isHealthKitSynchronized = false
                    self.persistHealthKitSyncState(false)
                    self.errorMessage = "Health access denied. You can enable permissions from iOS Settings > Health > Data Access."
                    self.isLoading = false
                }
                return
            }
            await MainActor.run {
                self.isHealthKitSynchronized = true
            }

            let snapshot = await healthService.fetchLatestSnapshot(profile: nil)
            await MainActor.run {
                if !self.containsImportedHealthMetrics(snapshot) {
                    self.healthImportState = .noData
                    self.isHealthKitSynchronized = true
                    self.persistHealthKitSyncState(true)
                    self.errorMessage = "No Health data available yet. If Apple Watch has data, make sure Health sync is complete."
                } else {
                    self.applyImportedMetrics(from: snapshot)
                }
                self.isLoading = false
            }
        }
    }

    func toggleHealthConcern(_ concern: HealthConcernOption) {
        if concern == .none {
            healthConcerns = [.none]
            return
        }

        if healthConcerns.contains(concern) {
            healthConcerns.remove(concern)
        } else {
            healthConcerns.insert(concern)
        }
        healthConcerns.remove(.none)

        if healthConcerns.isEmpty {
            healthConcerns = [.none]
        }
    }

    func toggleAccessOption(_ option: ExerciseAccessOptionQuestion) {
        if option == .none {
            accessOptions = [.none]
            return
        }

        if accessOptions.contains(option) {
            accessOptions.remove(option)
        } else {
            accessOptions.insert(option)
        }

        accessOptions.remove(.none)

        if accessOptions.isEmpty {
            accessOptions = [.none]
        }
    }

    func submit() {
        Task {
            await submitInternal()
        }
    }

    func continueAfterRecommendation() {
        onCompleted()
    }

    func finalizePendingGuestSubmissionIfNeeded() async {
        guard case .signedIn(let user) = authService.authState else { return }
        guard let pendingGuestProfile, let pendingGuestSportPlan else { return }

        do {
            try await firestoreUserRepository.saveProfile(userId: user.id, profile: pendingGuestProfile)
            try await firestoreUserRepository.saveSportPlan(userId: user.id, plan: pendingGuestSportPlan)
            self.pendingGuestProfile = nil
            self.pendingGuestSportPlan = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func submitInternal() async {
        isLoading = true
        errorMessage = nil
        recommendationSummary = nil

        normalizeSelections()
        guard validateMandatoryInputs() else {
            isLoading = false
            return
        }

        let profile = buildProfile()
        let goalFrequency = derivedGoalFrequency()

        do {
            // 1. Save profile locally (existing logic)
            try userProfileRepository.saveProfile(profile)
            try planRepository.saveGoal(goalFrequency)

            // 2. Generate recommendations from sports catalog and derive persisted sport plan phases
            let snapshot = await healthService.fetchLatestSnapshot(profile: profile)
            let request = RecommendationRequest(
                userProfile: profile, healthSnapshot: snapshot,
                goalFrequency: goalFrequency, weekStartDate: Date()
            )
            let result = recommendationEngine.recommend(request: request)
            let recommendedSports = [result.primary] + result.alternatives
            let sportPlan = buildSportPlan(
                profile: profile,
                recommendedSports: recommendedSports,
                fallbackWeeklySessions: max(1, result.weeklyPlan.sessions.count)
            )
            pendingGuestProfile = profile
            pendingGuestSportPlan = sportPlan

            // 3. Save to Firestore
            if case .signedIn(let user) = authService.authState {
                try await firestoreUserRepository.saveProfile(userId: user.id, profile: profile)
                try await firestoreUserRepository.saveSportPlan(userId: user.id, plan: sportPlan)
                pendingGuestProfile = nil
                pendingGuestSportPlan = nil
            }

            // 4. Keep existing local plan for offline support
            try planRepository.saveCurrentPlan(result.weeklyPlan)

            _ = await notificationService.requestAuthorization()
            notificationService.schedulePlanReminders(for: result.weeklyPlan)

            let maxScore = recommendedSports.map(\.score).max() ?? 1
            let planBySportName = Dictionary(
                uniqueKeysWithValues: sportPlan.sports.map {
                    (Self.normalizedToken($0.displayName), $0)
                }
            )

            recommendationSummary = RecommendationSummary(
                primaryActivityName: result.primary.displayName,
                sports: recommendedSports.map { recommendation in
                    let matchedPlan = planBySportName[Self.normalizedToken(recommendation.displayName)]
                    let initial = matchedPlan?.resolvedInitialPrescription
                    let target = matchedPlan?.resolvedTargetPrescription
                    let resolvedWeekOneFrequency = initial?.weeklyTargetCount ?? result.weeklyPlan.sessions.count
                    let resolvedWeekTwoPlusFrequency = target?.weeklyTargetCount ?? resolvedWeekOneFrequency
                    let resolvedWeekOneDuration = initial?.durationMinutes ?? recommendation.plannedDurationMinutes
                    let resolvedWeekTwoPlusDuration = target?.durationMinutes ?? resolvedWeekOneDuration
                    let resolvedProgression =
                        matchedPlan?.hasProgression
                        ?? (resolvedWeekOneFrequency != resolvedWeekTwoPlusFrequency || resolvedWeekOneDuration != resolvedWeekTwoPlusDuration)

                    return RecommendationSummary.SportFactor(
                        sportName: recommendation.displayName,
                        compatibilityPercent: Self.compatibilityPercent(
                            score: recommendation.score,
                            maxScore: maxScore
                        ),
                        hasProgression: resolvedProgression,
                        weekOneFrequency: resolvedWeekOneFrequency,
                        weekTwoPlusFrequency: resolvedWeekTwoPlusFrequency,
                        weekOneSessionMinutes: resolvedWeekOneDuration,
                        weekTwoPlusSessionMinutes: resolvedWeekTwoPlusDuration,
                        cautions: recommendation.cautions
                    )
                }
            )

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func buildSportPlan(
        profile: UserProfileInput,
        recommendedSports: [SportRecommendation],
        fallbackWeeklySessions: Int
    ) -> FirestoreSportPlan {
        let loader = SportsCatalogLoader.shared
        let rhrBand = profile.questionnaireCurrentRHRBand?.sportsJsonBand ?? CurrentRHRBandQuestion.from61To75.sportsJsonBand
        let bmiCategory = BMICalculator.category(
            heightCm: profile.heightCm, weightKg: profile.weightKg
        )
        let weekReset = Date().startOfWeek()
        var usedSportKeys = Set<String>()
        var sports: [FirestoreSportEntry] = []

        for recommendation in recommendedSports {
            let normalizedName = Self.normalizedToken(recommendation.displayName)
            guard !usedSportKeys.contains(normalizedName) else { continue }
            usedSportKeys.insert(normalizedName)

            let prescription =
                loader.prescription(
                    for: recommendation.displayName,
                    rhrBand: rhrBand,
                    bmiCategory: bmiCategory
                )
                ?? loader.prescription(
                    for: recommendation.displayName,
                    rhrBand: rhrBand,
                    bmiCategory: "Any BMI"
                )

            let initialDuration = prescription?.initial.durationMinutes ?? max(10, recommendation.plannedDurationMinutes)
            let targetDuration = prescription?.target.durationMinutes ?? initialDuration
            let initialWeekly = prescription?.initial.daysPerWeek ?? fallbackWeeklySessions
            let targetWeekly = prescription?.target.daysPerWeek ?? initialWeekly
            let hasProgression = prescription?.hasProgression ?? (initialDuration != targetDuration || initialWeekly != targetWeekly)

            sports.append(
                FirestoreSportEntry(
                    id: normalizedName,
                    displayName: recommendation.displayName,
                    weeklyTargetCount: initialWeekly,
                    completedThisWeek: 0,
                    durationMinutes: initialDuration,
                    weekResetDate: weekReset,
                    hasProgression: hasProgression,
                    initialPrescription: FirestoreSportPrescription(
                        weeklyTargetCount: initialWeekly,
                        durationMinutes: initialDuration
                    ),
                    targetPrescription: FirestoreSportPrescription(
                        weeklyTargetCount: targetWeekly,
                        durationMinutes: targetDuration
                    )
                )
            )
            if sports.count >= 3 { break }
        }

        return FirestoreSportPlan(generatedAt: Date(), sports: sports)
    }


    private func buildProfile() -> UserProfileInput {
        let resolvedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "ViRest User" : fullName
        let resolvedActivities: [ActivityType] = enjoyableActivities.isEmpty ? [.walking] : Array(enjoyableActivities)
        return UserProfileInput(
            fullName: resolvedName,
            age: Int(ageText),
            gender: gender,
            questionnaireCurrentRHRBand: questionnaireCurrentRHRBand,
            questionnaireTargetRHRGoal: questionnaireTargetRHRGoal,
            heightCm: parsedNumericValue(from: heightCmText),
            weightKg: parsedNumericValue(from: weightKgText),
            questionnaireHealthConcerns: normalizedHealthConcerns(),
            sessionDuration: sessionDuration,
            daysPerWeek: daysPerWeek,
            preferredTime: preferredTime,
            environment: environment,
            questionnaireAccessOptions: normalizedAccessOptions(),
            enjoyableActivities: resolvedActivities,
            intensityPreference: intensityPreference,
            socialPreference: socialPreference,
            consistency: consistency,
            cardioExperienceLevel: cardioExperienceLevel,
            acceptedDisclaimer: true,
            updatedAt: Date()
        )
    }

    private func normalizeSelections() {
        if healthConcerns.contains(.none), healthConcerns.count > 1 {
            healthConcerns.remove(.none)
        }

        if healthConcerns.isEmpty {
            healthConcerns.insert(.none)
        }

        if accessOptions.isEmpty {
            accessOptions.insert(.none)
        }

        if accessOptions.contains(.none), accessOptions.count > 1 {
            accessOptions.remove(.none)
        }
    }

    private func validateMandatoryInputs() -> Bool {
        let trimmedHeight = heightCmText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedHeight.isEmpty else {
            errorMessage = "Height is required."
            return false
        }

        guard let height = parsedNumericValue(from: trimmedHeight), height > 0 else {
            errorMessage = "Please input a valid height in cm."
            return false
        }

        let trimmedWeight = weightKgText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedWeight.isEmpty else {
            errorMessage = "Weight is required."
            return false
        }

        guard let weight = parsedNumericValue(from: trimmedWeight), weight > 0 else {
            errorMessage = "Please input a valid weight in kg."
            return false
        }

        if height < 80 || height > 250 {
            errorMessage = "Height seems out of range."
            return false
        }

        if weight < 20 || weight > 400 {
            errorMessage = "Weight seems out of range."
            return false
        }

        if healthConcerns.isEmpty {
            errorMessage = "Health condition is required."
            return false
        }

        if accessOptions.isEmpty {
            errorMessage = "At least one access option is required."
            return false
        }

        return true
    }

    private func parsedNumericValue(from rawValue: String) -> Double? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }

    private func containsImportedHealthMetrics(_ snapshot: HealthSnapshot) -> Bool {
        snapshot.heightCm != nil ||
        snapshot.weightKg != nil ||
        snapshot.restingHeartRate != nil
    }

    private func applyImportedMetrics(from snapshot: HealthSnapshot) {
        importedHealthSnapshot = snapshot
        healthImportState = .imported
        isHealthKitSynchronized = true
        persistHealthKitSyncState(true)
        errorMessage = nil

        if let height = snapshot.heightCm {
            heightCmText = String(format: "%.0f", height)
        }
        if let weight = snapshot.weightKg {
            weightKgText = String(format: "%.1f", weight)
        }
        if let rhr = snapshot.restingHeartRate {
            questionnaireCurrentRHRBand = Self.questionBand(from: rhr)
        }
    }

    private func normalizedHealthConcerns() -> [HealthConcernOption] {
        var list = Array(healthConcerns)
        if list.contains(.none), list.count > 1 {
            list.removeAll { $0 == .none }
        }
        return list.sorted { $0.displayName < $1.displayName }
    }

    private func normalizedAccessOptions() -> [ExerciseAccessOptionQuestion] {
        Array(accessOptions).sorted { $0.displayName < $1.displayName }
    }

    private func derivedGoalFrequency() -> WeeklyGoalFrequency {
        switch daysPerWeek {
        case .twoToThree:
            return .twoTimesPerWeek
        case .threeToFour:
            return .threeTimesPerWeek
        case .fourToFive, .fiveToSeven:
            return .fourPlusPerWeek
        }
    }

    private static func questionBand(from restingHeartRate: Double) -> CurrentRHRBandQuestion {
        switch restingHeartRate {
        case ..<61:
            return .upTo60
        case 61..<76:
            return .from61To75
        case 76..<91:
            return .from76To90
        default:
            return .above90
        }
    }

    private static func compatibilityPercent(score: Double, maxScore: Double) -> Int {
        guard maxScore > 0 else { return 0 }
        let raw = (score / maxScore) * 100
        let clamped = min(100, max(1, raw))
        return Int(clamped.rounded())
    }

    private static func normalizedToken(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "[^a-z0-9]+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
            .lowercased()
    }

    private func hasPersistedHealthKitSyncState() -> Bool {
        UserDefaults.standard.bool(forKey: Self.healthKitSynchronizedDefaultsKey)
    }

    private func persistHealthKitSyncState(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: Self.healthKitSynchronizedDefaultsKey)
    }
}
