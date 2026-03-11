import Foundation

enum ImpactLevel: String, Codable {
    case low
    case moderate
    case high
}

struct SportCatalogItem: Codable, Identifiable, Equatable {
    var id: UUID
    var activity: ActivityType
    var displayName: String
    var allowedEnvironments: [SportEnvironment]
    var requiredEquipments: [Equipment]
    var contraindicatedConditions: [HealthCondition]
    var contraindicatedInjuries: [InjuryLimitation]
    var impactLevel: ImpactLevel
    var defaultDurationRangeMinutes: ClosedRange<Int>
    var minRPE: Int
    var maxRPE: Int
    var baseCardioScore: Double
    var shortDescription: String

    init(
        id: UUID = UUID(),
        activity: ActivityType,
        displayName: String,
        allowedEnvironments: [SportEnvironment],
        requiredEquipments: [Equipment],
        contraindicatedConditions: [HealthCondition],
        contraindicatedInjuries: [InjuryLimitation],
        impactLevel: ImpactLevel,
        defaultDurationRangeMinutes: ClosedRange<Int>,
        minRPE: Int,
        maxRPE: Int,
        baseCardioScore: Double,
        shortDescription: String
    ) {
        self.id = id
        self.activity = activity
        self.displayName = displayName
        self.allowedEnvironments = allowedEnvironments
        self.requiredEquipments = requiredEquipments
        self.contraindicatedConditions = contraindicatedConditions
        self.contraindicatedInjuries = contraindicatedInjuries
        self.impactLevel = impactLevel
        self.defaultDurationRangeMinutes = defaultDurationRangeMinutes
        self.minRPE = minRPE
        self.maxRPE = maxRPE
        self.baseCardioScore = baseCardioScore
        self.shortDescription = shortDescription
    }
}

struct SportRecommendation: Codable, Identifiable, Equatable {
    var id: UUID
    var activity: ActivityType
    var displayName: String
    var score: Double
    var plannedDurationMinutes: Int
    var targetRPE: RPERange
    var reasons: [String]

    init(
        id: UUID = UUID(),
        activity: ActivityType,
        displayName: String,
        score: Double,
        plannedDurationMinutes: Int,
        targetRPE: RPERange,
        reasons: [String]
    ) {
        self.id = id
        self.activity = activity
        self.displayName = displayName
        self.score = score
        self.plannedDurationMinutes = plannedDurationMinutes
        self.targetRPE = targetRPE
        self.reasons = reasons
    }
}

struct RecommendationRequest {
    var userProfile: UserProfileInput
    var healthSnapshot: HealthSnapshot?
    var goalFrequency: WeeklyGoalFrequency
    var weekStartDate: Date
}

struct RecommendationResult: Equatable {
    var generatedAt: Date
    var primary: SportRecommendation
    var alternatives: [SportRecommendation]
    var weeklyPlan: WeeklyPlan
}
