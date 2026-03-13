import Foundation
import Combine
import SwiftData
import FirebaseFirestore

@MainActor
final class AppContainer: ObservableObject {
    let modelContainer: ModelContainer

    // Auth
    let authService: FirebaseAuthService

    // Firestore
    let firestoreUserRepository: FirestoreUserRepository

    // Services
    let healthService: HealthDataProviding
    let recommendationEngine: RecommendationProviding
    let planAdjustmentService: PlanAdjusting
    let notificationService: UserNotificationService
    let gamificationService: GamificationProviding

    // Local SwiftData (offline fallback)
    let userProfileRepository: UserProfileRepository
    let planRepository: PlanRepository
    let checkInRepository: CheckInRepository
    let badgeStateRepository: BadgeStateRepository

    init(inMemory: Bool = false) {
        let schema = Schema([KeyValueRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            self.modelContainer = try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("SwiftData init failed: \(error)")
        }

        let kv = SwiftDataKeyValueStore(modelContainer: modelContainer)
        self.userProfileRepository = UserProfileSwiftDataRepository(store: kv)
        self.planRepository = PlanSwiftDataRepository(store: kv)
        self.checkInRepository = CheckInSwiftDataRepository(store: kv)
        self.badgeStateRepository = BadgeStateSwiftDataRepository(store: kv)

        self.authService = FirebaseAuthService()
        self.firestoreUserRepository = FirestoreUserRepository()
        self.healthService = HealthKitService()
        self.recommendationEngine = RuleBasedRecommendationEngine()
        self.planAdjustmentService = RuleBasedPlanAdjustmentService()
        self.notificationService = UserNotificationService()
        self.gamificationService = GamificationService()
    }
}
