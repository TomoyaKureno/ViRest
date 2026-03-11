import Foundation

@MainActor
final class PlanSwiftDataRepository: PlanRepository {
    private let store: SwiftDataKeyValueStore

    init(store: SwiftDataKeyValueStore) {
        self.store = store
    }

    func loadGoal() throws -> WeeklyGoalFrequency? {
        try store.load(WeeklyGoalFrequency.self, forKey: StorageKeys.weeklyGoal)
    }

    func saveGoal(_ goal: WeeklyGoalFrequency) throws {
        try store.save(goal, forKey: StorageKeys.weeklyGoal)
    }

    func loadCurrentPlan() throws -> WeeklyPlan? {
        try store.load(WeeklyPlan.self, forKey: StorageKeys.currentPlan)
    }

    func saveCurrentPlan(_ plan: WeeklyPlan) throws {
        try store.save(plan, forKey: StorageKeys.currentPlan)
    }
}
