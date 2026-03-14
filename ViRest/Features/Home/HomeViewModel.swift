import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var firestoreUser: FirestoreUser?
    @Published var currentTitle: String = ""
    @Published var profileName: String = "ViRest User"
    @Published var currentRestingHRText: String = "-"
    @Published var currentWeightText: String = "-"
    @Published var currentHeightText: String = "-"
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var checkInSuccess: String?

    // Sheet state
    @Published var selectedSport: FirestoreSportEntry?
    @Published var showCheckInSheet = false

    private let firestoreUserRepository: FirestoreUserRepository
    private let userProfileRepository: UserProfileRepository
    private let authService: AuthProviding
    private let healthService: HealthDataProviding
    private let notificationService: NotificationScheduling
    private let gamificationService: GamificationProviding
    private let badgeRepository: BadgeStateRepository
    private let planAdjustmentService: PlanAdjusting

    init(
        firestoreUserRepository: FirestoreUserRepository,
        userProfileRepository: UserProfileRepository,
        authService: AuthProviding,
        healthService: HealthDataProviding,
        notificationService: NotificationScheduling,
        gamificationService: GamificationProviding,
        badgeRepository: BadgeStateRepository,
        planAdjustmentService: PlanAdjusting
    ) {
        self.firestoreUserRepository = firestoreUserRepository
        self.userProfileRepository = userProfileRepository
        self.authService = authService
        self.healthService = healthService
        self.notificationService = notificationService
        self.gamificationService = gamificationService
        self.badgeRepository = badgeRepository
        self.planAdjustmentService = planAdjustmentService
    }

    var sports: [FirestoreSportEntry] {
        firestoreUser?.sportPlan?.resolvedSports(at: Date()) ?? []
    }

    func load() {
        Task { await loadInternal() }
    }

    // Called when user taps '+' on a sport card
    func tapCheckIn(sport: FirestoreSportEntry) {
        selectedSport = sport
        showCheckInSheet = true
    }

    // Called by sheet's onCompleted closure to reload data
    func reloadAfterCheckIn() {
        Task { await loadInternal() }
        checkInSuccess = "Session logged!"
    }

    func makeCheckInSheetViewModel(for sport: FirestoreSportEntry) -> CheckInSheetViewModel {
        let vm = CheckInSheetViewModel(
            sport: sport,
            firestoreUserRepository: firestoreUserRepository,
            authService: authService,
            badgeRepository: badgeRepository,
            gamificationService: gamificationService,
            notificationService: notificationService,
            planAdjustmentService: planAdjustmentService
        )
        vm.onCompleted = { [weak self] in
            self?.reloadAfterCheckIn()
        }
        return vm
    }

    private func loadInternal() async {
        isLoading = true
        guard case .signedIn(let user) = authService.authState else {
            isLoading = false; return
        }
        do {
            var loadedBadgeState = try badgeRepository.loadState()
            let didChangeBadgeState = loadedBadgeState.normalizeRandomCriteriaIfNeeded()
            if didChangeBadgeState {
                try badgeRepository.saveState(loadedBadgeState)
            }

            firestoreUser = try await firestoreUserRepository.loadUser(userId: user.id)
            let localProfile = try userProfileRepository.loadProfile()
            currentTitle = loadedBadgeState.level.title
            updateProfileName(localProfile: localProfile)
            await updateVitals(localProfile: localProfile)
            try await resetWeeklyCountersIfNeeded(userId: user.id)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }

    private func updateProfileName(localProfile: UserProfileInput?) {
        let localName = localProfile?.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let localName, !localName.isEmpty {
            profileName = localName
            return
        }

        let remoteName = firestoreUser?.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let remoteName, !remoteName.isEmpty {
            profileName = remoteName
            return
        }

        profileName = "ViRest User"
    }

    private func updateVitals(localProfile: UserProfileInput?) async {
        let snapshot = await healthService.fetchLatestSnapshot(profile: localProfile)

        let resolvedHeight = snapshot.heightCm ?? localProfile?.heightCm
        let resolvedWeight = snapshot.weightKg ?? localProfile?.weightKg
        let resolvedRHR = snapshot.restingHeartRate.map { Int($0.rounded()) }
            ?? localProfile?.questionnaireCurrentRHRBand?.representativeBPM
            ?? firestoreUser?.restingHeartRate

        if let resolvedRHR {
            currentRestingHRText = "\(resolvedRHR) bpm"
        } else {
            currentRestingHRText = "-"
        }

        if let resolvedWeight {
            currentWeightText = formatWeight(resolvedWeight)
        } else {
            currentWeightText = "-"
        }

        if let resolvedHeight {
            currentHeightText = String(format: "%.0f cm", resolvedHeight)
        } else {
            currentHeightText = "-"
        }
    }

    private func formatWeight(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if abs(rounded.rounded() - rounded) < 0.01 {
            return String(format: "%.0f kg", rounded)
        }
        return String(format: "%.1f kg", rounded)
    }

    private func resetWeeklyCountersIfNeeded(userId: String) async throws {
        guard var plan = firestoreUser?.sportPlan else { return }
        let weekStart = Date().startOfWeek()
        guard plan.sports.contains(where: { $0.weekResetDate < weekStart }) else { return }

        for i in plan.sports.indices {
            plan.sports[i].completedThisWeek = 0
            plan.sports[i].weekResetDate = weekStart
        }
        firestoreUser?.sportPlan = plan
        try await firestoreUserRepository.saveSportPlan(userId: userId, plan: plan)
    }
}
