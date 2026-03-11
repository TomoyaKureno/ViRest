import Foundation
import Combine
import SwiftData

@MainActor
final class AppContainer: ObservableObject {
    let modelContainer: ModelContainer

    let authService: FirebaseAuthService
    let healthService: HealthDataProviding
    let recommendationEngine: RecommendationProviding
    let planAdjustmentService: PlanAdjusting
    let notificationService: NotificationScheduling
    let gamificationService: GamificationProviding

    let userProfileRepository: UserProfileRepository
    let planRepository: PlanRepository
    let checkInRepository: CheckInRepository
    let badgeStateRepository: BadgeStateRepository

    init(inMemory: Bool = false) {
        let schema = Schema([
            KeyValueRecord.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)

        do {
            self.modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Failed to initialize SwiftData container: \(error.localizedDescription)")
        }

        let keyValueStore = SwiftDataKeyValueStore(modelContainer: modelContainer)
        self.userProfileRepository = UserProfileSwiftDataRepository(store: keyValueStore)
        self.planRepository = PlanSwiftDataRepository(store: keyValueStore)
        self.checkInRepository = CheckInSwiftDataRepository(store: keyValueStore)
        self.badgeStateRepository = BadgeStateSwiftDataRepository(store: keyValueStore)

        self.authService = FirebaseAuthService()
        self.healthService = HealthKitService()
        self.recommendationEngine = RuleBasedRecommendationEngine()
        self.planAdjustmentService = RuleBasedPlanAdjustmentService()
        self.notificationService = UserNotificationService()
        self.gamificationService = GamificationService()
    }
}
