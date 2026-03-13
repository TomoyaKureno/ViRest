import Foundation
import Combine

@MainActor
final class OnboardingViewModel: ObservableObject {
    struct RecommendationSummary: Equatable {
        let activityName: String
        let frequencyPerWeek: Int
        let plannedDurationMinutes: Int
        let cautions: [String]
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

    @Published var sessionDuration: SessionDurationOption = .twentyToThirty
    @Published var daysPerWeek: DaysPerWeekAvailability = .threeToFour
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
    }

    func autoImportHealthDataIfNeeded() {
        guard !didAttemptAutoImport else { return }
        didAttemptAutoImport = true
        importHealthData()
    }

    func shouldPresentHealthKitPrompt() async -> Bool {
        await healthService.shouldPresentAuthorizationPrompt()
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
                        self.questionnaireCurrentRHRBand = Self.questionBand(from: rhr)
                    }
                } else {
                    self.healthImportState = .noData
                    self.errorMessage = "No Health data available yet. If Apple Watch has data, make sure Health sync is complete."
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

    func submitAndCompleteIfValid() {
        Task {
            await submitInternal()
            if recommendationSummary != nil {
                onCompleted()
            }
        }
    }

    func continueAfterRecommendation() {
        onCompleted()
    }

    private func submitInternal() async {
        isLoading = true
        errorMessage = nil

        guard acceptedDisclaimer else {
            errorMessage = "Please accept the medical disclaimer."
            isLoading = false; return
        }
        guard !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please fill in your name."
            isLoading = false; return
        }

        normalizeSelections()
        let profile = buildProfile()
        let goalFrequency = derivedGoalFrequency()

        do {
            // 1. Save profile locally (existing logic)
            try userProfileRepository.saveProfile(profile)
            try planRepository.saveGoal(goalFrequency)

            // 2. Generate top-3 sport plan using sports.json
            let sportPlan = buildSportPlan(profile: profile)

            // 3. Save to Firestore
            guard case .signedIn(let user) = authService.authState else {
                throw AppError.auth("Not authenticated")
            }
            try await firestoreUserRepository.saveProfile(userId: user.id, profile: profile)
            try await firestoreUserRepository.saveSportPlan(userId: user.id, plan: sportPlan)

            // 4. Keep existing local plan for offline support
            let snapshot = await healthService.fetchLatestSnapshot(profile: profile)
            let request = RecommendationRequest(
                userProfile: profile, healthSnapshot: snapshot,
                goalFrequency: weeklyGoal, weekStartDate: Date()
            )
            let result = recommendationEngine.recommend(request: request)
            try planRepository.saveCurrentPlan(result.weeklyPlan)

            _ = await notificationService.requestAuthorization()
            notificationService.schedulePlanReminders(for: result.weeklyPlan)

            recommendationSummary = RecommendationSummary(
                activityName: result.primary.displayName,
                frequencyPerWeek: result.weeklyPlan.sessions.count,
                plannedDurationMinutes: result.primary.plannedDurationMinutes,
                cautions: result.primary.cautions
            )

            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func buildSportPlan(profile: UserProfileInput) -> FirestoreSportPlan {
        let loader = SportsCatalogLoader.shared
        let rhrBand = profile.restingHeartRateRange.sportsJsonBand
        let bmiCategory = BMICalculator.category(
            heightCm: profile.heightCm, weightKg: profile.weightKg
        )
        let userEnv = profile.environment.rawValue.capitalized
        let userContraindications = profile.healthConditions.map { $0.displayName }

        print("🏃 Building plan — RHR band: \(rhrBand), BMI: \(bmiCategory), env: \(userEnv)")
        print("🏃 Total exercises available: \(loader.exercises.count)")

        var scored: [(name: String, prescription: SportPrescription, score: Double)] = []

        for exercise in loader.exercises {
            // Try exact RHR band first, then fall back to any available band
            guard let presc = loader.prescription(
                for: exercise.name,
                rhrBand: rhrBand,
                bmiCategory: bmiCategory
            ) else { continue }

            // Skip if any contraindication matches user's conditions
            let isContraindicated = presc.contraindications.contains { contra in
                userContraindications.contains {
                    $0.localizedCaseInsensitiveContains(contra) ||
                    contra.localizedCaseInsensitiveContains($0)
                }
            }
            if isContraindicated { continue }

            var score = 50.0

            // Environment match bonus
            let envMatch = exercise.environment == "Both"
                || exercise.environment == userEnv
                || profile.environment == .both
            if envMatch { score += 20 }

            // Enjoyable activity match bonus
            let activityMatch = profile.enjoyableActivities.contains { act in
                exercise.name.localizedCaseInsensitiveContains(act.displayName) ||
                act.displayName.localizedCaseInsensitiveContains(exercise.name)
            }
            if activityMatch { score += 30 }

            scored.append((name: exercise.name, prescription: presc, score: score))
        }

        print("🏃 Scored \(scored.count) eligible exercises")

        // If still empty (very restrictive profile), grab ANY 3 exercises with any band/BMI
        if scored.isEmpty {
            print("⚠️ No exercises matched — using fallback scoring")
            for exercise in loader.exercises {
                guard let presc = loader.prescription(
                    for: exercise.name,
                    rhrBand: rhrBand,
                    bmiCategory: "Any BMI"
                ) ?? loader.prescription(
                    for: exercise.name,
                    rhrBand: exercise.rhrBands.first?.rhrBand ?? rhrBand,
                    bmiCategory: bmiCategory
                ) else { continue }

                scored.append((name: exercise.name, prescription: presc, score: 50.0))
                if scored.count >= 3 { break }
            }
        }

        // Take top 3
        let top3 = scored.sorted { $0.score > $1.score }.prefix(3)
        print("🏃 Top 3: \(top3.map { $0.name })")

        let weekReset = Date().startOfWeek()
        let sports = top3.map { item in
            FirestoreSportEntry(
                id: item.name.lowercased().replacingOccurrences(of: " ", with: "_"),
                displayName: item.name,
                weeklyTargetCount: item.prescription.minDaysPerWeek,
                completedThisWeek: 0,
                durationMinutes: item.prescription.minDurationMinutes,
                weekResetDate: weekReset
            )
        }

        return FirestoreSportPlan(generatedAt: Date(), sports: Array(sports))
    }


    private func buildProfile() -> UserProfileInput {
        let resolvedName = fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "ViRest User" : fullName
        return UserProfileInput(
            fullName: resolvedName,
            age: Int(ageText),
            gender: gender,
            questionnaireCurrentRHRBand: questionnaireCurrentRHRBand,
            questionnaireTargetRHRGoal: questionnaireTargetRHRGoal,
            heightCm: Double(heightCmText),
            weightKg: Double(weightKgText),
            questionnaireHealthConcerns: normalizedHealthConcerns(),
            sessionDuration: sessionDuration,
            daysPerWeek: daysPerWeek,
            preferredTime: preferredTime,
            environment: environment,
            questionnaireAccessOptions: normalizedAccessOptions(),
            enjoyableActivities: Array(enjoyableActivities),
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
        guard let height = Double(heightCmText), height > 0 else {
            errorMessage = "Height is required."
            return false
        }

        guard let weight = Double(weightKgText), weight > 0 else {
            errorMessage = "Weight is required."
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
}
