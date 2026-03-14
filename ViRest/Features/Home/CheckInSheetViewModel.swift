//
//  CheckInSheetViewModel.swift
//  ViRest
//
//  Created by Joshua Valentine Manik on 13/03/26.
//

import Foundation
import Combine

extension CheckInSheetViewModel: Identifiable {
    var id: String { sport.id }  // make sport non-private or add a computed id
}

@MainActor
final class CheckInSheetViewModel: ObservableObject {

    enum SheetState {
        case form
        case result
    }

    @Published var state: SheetState = .form
    @Published var difficulty: ActivityDifficulty = .moderate
    @Published var fatigue: FatigueLevel = .moderatelyTired
    @Published var painLevel: PainLevel = .noPain
    @Published var discomfortAreas: Set<DiscomfortArea> = []
    @Published var notes: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    // Result state
    @Published var assessment: SuitabilityAssessment?
    @Published var appreciationText: String?
    @Published var newBadges: [BadgeEarned] = []
    @Published var newTitleName: String?

    private let sport: FirestoreSportEntry
    private let firestoreUserRepository: FirestoreUserRepository
    private let authService: AuthProviding
    private let badgeRepository: BadgeStateRepository
    private let gamificationService: GamificationProviding
    private let notificationService: NotificationScheduling
    private let planAdjustmentService: PlanAdjusting

    // Called when submit succeeds so HomeViewModel can reload
    var onCompleted: (() -> Void)?

    init(
        sport: FirestoreSportEntry,
        firestoreUserRepository: FirestoreUserRepository,
        authService: AuthProviding,
        badgeRepository: BadgeStateRepository,
        gamificationService: GamificationProviding,
        notificationService: NotificationScheduling,
        planAdjustmentService: PlanAdjusting
    ) {
        self.sport = sport
        self.firestoreUserRepository = firestoreUserRepository
        self.authService = authService
        self.badgeRepository = badgeRepository
        self.gamificationService = gamificationService
        self.notificationService = notificationService
        self.planAdjustmentService = planAdjustmentService
    }

    func submit() {
        Task { await submitInternal() }
    }

    private func submitInternal() async {
        isLoading = true
        errorMessage = nil

        guard case .signedIn(let user) = authService.authState else {
            errorMessage = "Not authenticated."
            isLoading = false
            return
        }

        do {
            let resolvedActivity = activityType(for: sport.displayName)

            // 1. Record check-in counter in Firestore
            try await firestoreUserRepository.recordCheckIn(
                userId: user.id,
                sportId: sport.id
            )

            // 2. Save check-in history entry
            try await firestoreUserRepository.saveCheckInHistory(
                userId: user.id,
                sportId: sport.id,
                sportName: sport.displayName,
                durationMinutes: sport.durationMinutes
            )

            // 3. Evaluate gamification (badges + level title) via existing service
            let fakeCheckIn = SessionCheckIn(
                sessionId: UUID(),
                checkInDate: Date(),
                activity: resolvedActivity,
                actualDurationMinutes: sport.durationMinutes,
                activityDifficulty: difficulty,
                fatigueLevel: fatigue,
                painLevel: painLevel,
                discomfortAreas: painLevel == .noPain ? [] : Array(discomfortAreas),
                notes: notes
            )
            let existingState = try badgeRepository.loadState()
            let gamification = gamificationService.evaluate(after: fakeCheckIn, current: existingState)
            try badgeRepository.saveState(gamification.updatedState)
            appreciationText = gamification.appreciationMessage
            newBadges = gamification.newlyEarnedBadges
            let levelIncreased = gamification.updatedState.level.rawValue > existingState.level.rawValue
            newTitleName = levelIncreased ? gamification.updatedState.level.title : nil

            // 4. Build suitability assessment from answers
            assessment = buildAssessment()

            // 5. Schedule notifications
            notificationService.scheduleTargetAchievedNotification(for: resolvedActivity)

            isLoading = false
            state = .result
            onCompleted?()

        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func buildAssessment() -> SuitabilityAssessment {
        let zone: SuitabilityZone
        let score: Double
        let decision: ProgressionDecision
        var reasons: [String] = []
        let recommendationText: String

        switch (difficulty, fatigue, painLevel) {
        case (.tooExhausting, _, _),
             (_, .completelyExhausted, _),
             (_, _, .strongPain),
             (_, _, .moderatePain):
            zone = .red
            score = 30
            decision = .downgradeIntensity
            reasons.append("Activity was too intense for your current state.")
            recommendationText = "Rest and recover before your next session."

        case (.veryHard, .veryTired, _),
             (_, .veryTired, _),
             (_, _, .mildDiscomfort):
            zone = .yellow
            score = 55
            decision = .reduceVolume
            reasons.append("Consider reducing intensity next session.")
            recommendationText = "You are making progress. Ease up slightly if needed."

        default:
            zone = .green
            score = 85
            decision = .keep
            reasons.append("Great effort — activity level looks appropriate.")
            recommendationText = "Keep going — this activity suits you well."
        }

        if painLevel != .noPain {
            reasons.append("Pain was reported — monitor this area next session.")
        }

        return SuitabilityAssessment(
            zone: zone,
            score: score,
            reasons: reasons,
            decision: decision,
            recommendationText: recommendationText
        )
    }

    private func activityType(for sportName: String) -> ActivityType {
        switch normalizedToken(sportName) {
        case normalizedToken("Brisk walking"): return .briskWalking
        case normalizedToken("Trail walking"): return .trailWalking
        case normalizedToken("Nordic walking"): return .nordicWalking
        case normalizedToken("Flat walking"): return .flatWalking
        case normalizedToken("Walking"): return .walkingGeneral
        case normalizedToken("Interval walking"): return .intervalWalking
        case normalizedToken("Jogging"): return .jogging
        case normalizedToken("Run-walk intervals"): return .runWalkIntervals
        case normalizedToken("Road cycling"): return .roadCycling
        case normalizedToken("Stationary cycling"): return .stationaryCycling
        case normalizedToken("Recumbent cycling"): return .recumbentCycling
        case normalizedToken("Elliptical trainer"): return .ellipticalTrainer
        case normalizedToken("Rowing machine"): return .rowingMachineCardio
        case normalizedToken("Lap swimming"): return .lapSwimming
        case normalizedToken("Dance cardio"): return .danceCardio
        case normalizedToken("Stair climber"): return .stairClimber
        case normalizedToken("Stair walking"): return .stairWalking
        case normalizedToken("Pool walking"): return .poolWalking
        case normalizedToken("Aqua jogging"): return .aquaJogging
        case normalizedToken("Vinyasa yoga"): return .vinyasaYoga
        case normalizedToken("Yoga"): return .yoga
        case normalizedToken("Restorative yoga"): return .restorativeYoga
        case normalizedToken("Chair marching"): return .chairMarching
        case normalizedToken("Chair aerobics"): return .chairAerobics
        case normalizedToken("Tai chi"): return .taiChi
        default: return .walking
        }
    }

    private func normalizedToken(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "[^a-z0-9]+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
            .lowercased()
    }
}
