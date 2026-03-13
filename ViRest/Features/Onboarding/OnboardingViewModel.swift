import Foundation
import Combine

@MainActor
final class OnboardingViewModel: ObservableObject {
    
    private let firestoreUserRepository: FirestoreUserRepository
    private let authService: AuthProviding
    
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
            errorMessage = "Please accept the medical disclaimer."
            isLoading = false; return
        }
        guard !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please fill in your name."
            isLoading = false; return
        }

        normalizeSelections()
        let profile = buildProfile()

        do {
            // 1. Save profile locally (existing logic)
            try userProfileRepository.saveProfile(profile)
            try planRepository.saveGoal(weeklyGoal)

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

            isLoading = false
            onCompleted()
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
