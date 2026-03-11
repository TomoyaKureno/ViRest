import Foundation

enum HealthDataSource: String, Codable {
    case healthKit = "health_kit"
    case manual
    case mixed
}

struct HealthSnapshot: Codable, Equatable {
    var collectedAt: Date
    var source: HealthDataSource
    var stepCount: Double?
    var activeEnergyKCal: Double?
    var heightCm: Double?
    var weightKg: Double?
    var bmi: Double?
    var restingHeartRate: Double?
    var walkingHeartRateAverage: Double?
    var peakHeartRate: Double?
    var heartRateRecovery: Double?
    var vo2Max: Double?
    var dataFreshnessHours: Double?

    static func manualFallback(from profile: UserProfileInput) -> HealthSnapshot {
        let resting = profile.restingHeartRateRange.midpoint
        let heightCm = profile.heightCm
        let weightKg = profile.weightKg
        let bmi: Double?

        if let h = heightCm, let w = weightKg, h > 0 {
            let meter = h / 100
            bmi = w / (meter * meter)
        } else {
            bmi = nil
        }

        return HealthSnapshot(
            collectedAt: Date(),
            source: .manual,
            stepCount: nil,
            activeEnergyKCal: nil,
            heightCm: heightCm,
            weightKg: weightKg,
            bmi: bmi,
            restingHeartRate: resting,
            walkingHeartRateAverage: nil,
            peakHeartRate: nil,
            heartRateRecovery: nil,
            vo2Max: nil,
            dataFreshnessHours: nil
        )
    }
}

enum HealthAuthorizationState: Equatable {
    case unavailable
    case notDetermined
    case denied
    case authorized
}
