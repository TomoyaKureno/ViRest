import Foundation

#if os(iOS)
import HealthKit

@MainActor
final class HealthKitService: HealthDataProviding {
    private let store = HKHealthStore()

    var authorizationState: HealthAuthorizationState {
        guard HKHealthStore.isHealthDataAvailable() else {
            return .unavailable
        }

        guard let type = HKObjectType.quantityType(forIdentifier: .restingHeartRate) else {
            return .notDetermined
        }

        switch store.authorizationStatus(for: type) {
        case .notDetermined:
            return .notDetermined
        case .sharingDenied:
            return .denied
        case .sharingAuthorized:
            return .authorized
        @unknown default:
            return .notDetermined
        }
    }

    func shouldPresentAuthorizationPrompt() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            return false
        }

        let readTypes = requiredReadTypes()
        guard !readTypes.isEmpty else {
            return false
        }

        return await withCheckedContinuation { continuation in
            store.getRequestStatusForAuthorization(toShare: [], read: readTypes) { status, _ in
                switch status {
                case .shouldRequest:
                    continuation.resume(returning: true)
                case .unnecessary, .unknown:
                    continuation.resume(returning: false)
                @unknown default:
                    continuation.resume(returning: false)
                }
            }
        }
    }

    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            return false
        }

        let readTypes = requiredReadTypes()
        guard !readTypes.isEmpty else {
            return false
        }

        return await withCheckedContinuation { continuation in
            store.requestAuthorization(toShare: [], read: readTypes) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }

    func fetchLatestSnapshot(profile: UserProfileInput?) async -> HealthSnapshot {
        guard HKHealthStore.isHealthDataAvailable() else {
            if let profile {
                return HealthSnapshot.manualFallback(from: profile)
            }

            return HealthSnapshot(
                collectedAt: Date(),
                source: .manual,
                stepCount: nil,
                activeEnergyKCal: nil,
                heightCm: nil,
                weightKg: nil,
                bmi: nil,
                restingHeartRate: nil,
                walkingHeartRateAverage: nil,
                peakHeartRate: nil,
                heartRateRecovery: nil,
                vo2Max: nil,
                dataFreshnessHours: nil
            )
        }

        async let heightMeters = latestQuantity(identifier: .height, unit: .meter())
        async let weightKg = latestQuantity(identifier: .bodyMass, unit: .gramUnit(with: .kilo))
        async let restingHR = latestQuantity(identifier: .restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()))

        let collectedAt = Date()
        let heightCmValue = (await heightMeters).map { $0 * 100 }
        let weightKgValue = await weightKg
        let restingHRValue = await restingHR

        let hasHealthData = heightCmValue != nil || weightKgValue != nil || restingHRValue != nil

        if !hasHealthData {
            if let profile {
                return HealthSnapshot.manualFallback(from: profile)
            }

            return HealthSnapshot(
                collectedAt: collectedAt,
                source: .manual,
                ageYears: nil,
                biologicalGender: nil,
                stepCount: nil,
                activeEnergyKCal: nil,
                heightCm: nil,
                weightKg: nil,
                bmi: nil,
                restingHeartRate: nil,
                walkingHeartRateAverage: nil,
                peakHeartRate: nil,
                heartRateRecovery: nil,
                vo2Max: nil,
                dataFreshnessHours: nil
            )
        }

        let bmiValue: Double?

        if let h = heightCmValue, let w = weightKgValue, h > 0 {
            let meter = h / 100
            bmiValue = w / (meter * meter)
        } else {
            bmiValue = nil
        }

        let manualResting = profile?.questionnaireCurrentRHRBand.map { Double($0.representativeBPM) }
        let resolvedResting = restingHRValue ?? manualResting
        let usedManualFallbackValues = profile != nil && (heightCmValue == nil || weightKgValue == nil || restingHRValue == nil)
        let source: HealthDataSource = usedManualFallbackValues ? .mixed : .healthKit

        return HealthSnapshot(
            collectedAt: collectedAt,
            source: source,
            ageYears: profile?.age,
            biologicalGender: profile?.gender,
            stepCount: nil,
            activeEnergyKCal: nil,
            heightCm: heightCmValue ?? profile?.heightCm,
            weightKg: weightKgValue ?? profile?.weightKg,
            bmi: bmiValue,
            restingHeartRate: resolvedResting,
            walkingHeartRateAverage: nil,
            peakHeartRate: nil,
            heartRateRecovery: nil,
            vo2Max: nil,
            dataFreshnessHours: 0
        )
    }

    private func latestQuantity(identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }

                continuation.resume(returning: sample.quantity.doubleValue(for: unit))
            }

            store.execute(query)
        }
    }

    private func requiredReadTypes() -> Set<HKObjectType> {
        let quantityTypes = [
            HKObjectType.quantityType(forIdentifier: .height),
            HKObjectType.quantityType(forIdentifier: .bodyMass),
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)
        ].compactMap { $0 as HKObjectType? }
        
        return Set(quantityTypes)
    }
}

#else

@MainActor
final class HealthKitService: HealthDataProviding {
    var authorizationState: HealthAuthorizationState { .unavailable }

    func shouldPresentAuthorizationPrompt() async -> Bool { false }

    func requestAuthorization() async -> Bool { false }

    func fetchLatestSnapshot(profile: UserProfileInput?) async -> HealthSnapshot {
        if let profile {
            return HealthSnapshot.manualFallback(from: profile)
        }

        return HealthSnapshot(
            collectedAt: Date(),
            source: .manual,
            ageYears: profile?.age,
            biologicalGender: profile?.gender,
            stepCount: nil,
            activeEnergyKCal: nil,
            heightCm: nil,
            weightKg: nil,
            bmi: nil,
            restingHeartRate: nil,
            walkingHeartRateAverage: nil,
            peakHeartRate: nil,
            heartRateRecovery: nil,
            vo2Max: nil,
            dataFreshnessHours: nil
        )
    }
}

#endif
