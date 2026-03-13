import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var firestoreUser: FirestoreUser?
    @Published var currentTitle: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var checkInSuccess: String?

    // Sheet state
    @Published var selectedSport: FirestoreSportEntry?
    @Published var showCheckInSheet = false

    private let firestoreUserRepository: FirestoreUserRepository
    private let authService: AuthProviding
    private let notificationService: NotificationScheduling
    private let gamificationService: GamificationProviding
    private let badgeRepository: BadgeStateRepository
    private let planAdjustmentService: PlanAdjusting

    init(
        firestoreUserRepository: FirestoreUserRepository,
        authService: AuthProviding,
        notificationService: NotificationScheduling,
        gamificationService: GamificationProviding,
        badgeRepository: BadgeStateRepository,
        planAdjustmentService: PlanAdjusting
    ) {
        self.firestoreUserRepository = firestoreUserRepository
        self.authService = authService
        self.notificationService = notificationService
        self.gamificationService = gamificationService
        self.badgeRepository = badgeRepository
        self.planAdjustmentService = planAdjustmentService
    }

    var sports: [FirestoreSportEntry] {
        firestoreUser?.sportPlan?.sports ?? []
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
            firestoreUser = try await firestoreUserRepository.loadUser(userId: user.id)
            if let titleId = firestoreUser?.currentTitleId, !titleId.isEmpty {
                currentTitle = await FirestoreDB.shared.fetchTitleName(titleId: titleId)
            }
            try await resetWeeklyCountersIfNeeded(userId: user.id)
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
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
