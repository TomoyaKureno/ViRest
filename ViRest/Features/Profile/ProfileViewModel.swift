import Foundation
import Combine
import FirebaseFirestore

struct CheckInHistoryEntry: Codable, Identifiable {
    @DocumentID var id: String?
    var sportId: String
    var sportName: String
    var date: Date
    var durationMinutes: Int
}

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var profile: UserProfileInput?
    @Published var badgeState: BadgeState = .default
    @Published var weeklyGoal: WeeklyGoalFrequency = .threeTimesPerWeek
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?
    @Published var firestoreUser: FirestoreUser?
    @Published var currentTitle: FirestoreTitle?
    @Published var allTitles: [FirestoreTitle] = []
    @Published var checkInHistory: [CheckInHistoryEntry] = []


    private let userProfileRepository: UserProfileRepository
    private let planRepository: PlanRepository
    private let badgeRepository: BadgeStateRepository
    private let firestoreUserRepository: FirestoreUserRepository
    private let authService: AuthProviding


    init(
        userProfileRepository: UserProfileRepository,
        planRepository: PlanRepository,
        badgeRepository: BadgeStateRepository,
        firestoreUserRepository: FirestoreUserRepository,
        authService: AuthProviding
    ) {
        self.userProfileRepository = userProfileRepository
        self.planRepository = planRepository
        self.badgeRepository = badgeRepository
        self.firestoreUserRepository = firestoreUserRepository
        self.authService = authService
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
        guard case .signedIn(let user) = authService.authState else {
            isLoading = false; return
        }
        do {
            firestoreUser = try await firestoreUserRepository.loadUser(userId: user.id)

            // Load all titles for progress display
            let db = Firestore.firestore()
            let snapshot = try await db.collection("titles")
                .order(by: "displayOrder").getDocuments()
            allTitles = try snapshot.documents.map { try $0.data(as: FirestoreTitle.self) }

            // Identify current title
            if let titleId = firestoreUser?.currentTitleId {
                currentTitle = allTitles.first { $0.id == titleId }
            }

            // Keep local SwiftData in sync (for offline fallback)
            profile = try userProfileRepository.loadProfile()
            weeklyGoal = try planRepository.loadGoal() ?? .threeTimesPerWeek
            badgeState = try badgeRepository.loadState()
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
    
    func loadCheckInHistory() {
        Task {
            guard case .signedIn(let user) = authService.authState else { return }
            do {
                checkInHistory = try await firestoreUserRepository.loadCheckInHistory(userId: user.id)
            } catch {
                // Non-fatal — just leave history empty
                print("Could not load check-in history: \(error)")
            }
        }
    }


    private func updateGoalInternal() async {
        // Goal is intentionally locked after onboarding in current product policy.
        infoMessage = "Weekly goal is locked after initial setup."
    }
}
