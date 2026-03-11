import Foundation

protocol UserProfileRepository {
    func loadProfile() throws -> UserProfileInput?
    func saveProfile(_ profile: UserProfileInput) throws
}

protocol PlanRepository {
    func loadGoal() throws -> WeeklyGoalFrequency?
    func saveGoal(_ goal: WeeklyGoalFrequency) throws
    func loadCurrentPlan() throws -> WeeklyPlan?
    func saveCurrentPlan(_ plan: WeeklyPlan) throws
}

protocol CheckInRepository {
    func loadCheckIns() throws -> [SessionCheckIn]
    func addCheckIn(_ checkIn: SessionCheckIn) throws
}

protocol BadgeStateRepository {
    func loadState() throws -> BadgeState
    func saveState(_ state: BadgeState) throws
}
