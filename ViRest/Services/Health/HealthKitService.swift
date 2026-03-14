import Foundation

#if os(iOS)
import HealthKit

@MainActor
final class HealthKitService: HealthDataProviding {
    private let store = HKHealthStore()

    // NOTE: authorizationStatus only reflects WRITE permission on iOS.
    // For read types Apple always returns .notDetermined — this is by design.
    // We therefore never gate fetchLatestSnapshot on this status.
    var authorizationState: HealthAuthorizationState {
        guard HKHealthStore.isHealthDataAvailable() else {
            return .unavailable
        }
        return .authorized  // Treat as authorized — actual read access checked at query time
    }

    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }

        let identifiers: [HKQuantityTypeIdentifier] = [
            .stepCount,
            .activeEnergyBurned,
            .height,
            .bodyMass,
            .restingHeartRate,
            .walkingHeartRateAverage,
            .heartRate,
            .vo2Max,
            .heartRateRecoveryOneMinute
        ]
        let readTypes = Set(identifiers.compactMap { HKObjectType.quantityType(forIdentifier: $0) })

        return await withCheckedContinuation { continuation in
            store.requestAuthorization(toShare: [], read: readTypes) { success, error in
                if let error { print("⚠️ HealthKit auth error: \(error)") }
                // success here just means the dialog was shown — not that user approved
                // We always return true so fetching is attempted
                continuation.resume(returning: true)
            }
        }
    }

    func fetchLatestSnapshot(profile: UserProfileInput?) async -> HealthSnapshot {
        guard HKHealthStore.isHealthDataAvailable() else {
            if let profile { return HealthSnapshot.manualFallback(from: profile) }
            return emptySnapshot()
        }

        // Fetch all in parallel — queries return nil if user denied that specific type
        async let stepCount   = sumQuantity(identifier: .stepCount, unit: .count(), forLastDays: 7)
        async let activeEnergy = sumQuantity(identifier: .activeEnergyBurned, unit: .kilocalorie(), forLastDays: 7)
        async let heightMeters = latestQuantity(identifier: .height, unit: .meter())
        async let weightKg    = latestQuantity(identifier: .bodyMass, unit: .gramUnit(with: .kilo))
        async let restingHR   = latestQuantity(identifier: .restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()))
        async let walkingHR   = latestQuantity(identifier: .walkingHeartRateAverage, unit: HKUnit.count().unitDivided(by: .minute()))
        async let peakHR      = maxQuantity(identifier: .heartRate, unit: HKUnit.count().unitDivided(by: .minute()), forLastDays: 7)
        async let vo2         = latestQuantity(identifier: .vo2Max, unit: HKUnit(from: "ml/kg*min"))
        async let recovery    = latestQuantity(identifier: .heartRateRecoveryOneMinute, unit: HKUnit.count().unitDivided(by: .minute()))

        let heightCmValue  = await heightMeters.map { $0 * 100 }
        let weightKgValue  = await weightKg
        let restingHRValue = await restingHR

        // Log what came back so we can debug on device
        print("🏥 HealthKit fetch results:")
        print("   height: \(heightCmValue.map { String(format: "%.1f cm", $0) } ?? "nil")")
        print("   weight: \(weightKgValue.map { String(format: "%.1f kg", $0) } ?? "nil")")
        print("   restingHR: \(restingHRValue.map { String(format: "%.0f bpm", $0) } ?? "nil")")

        let bmiValue: Double?
        if let h = heightCmValue, let w = weightKgValue, h > 0 {
            let meter = h / 100
            bmiValue = w / (meter * meter)
        } else {
            bmiValue = nil
        }

        // Fallback: if HealthKit returned nil for RHR, use manual profile midpoint
        let resolvedRHR = restingHRValue ?? profile?.restingHeartRateRange.midpoint
        let resolvedHeight = heightCmValue ?? profile?.heightCm
        let resolvedWeight = weightKgValue ?? profile?.weightKg

        let source: HealthDataSource
        if restingHRValue != nil || heightCmValue != nil || weightKgValue != nil {
            source = .healthKit
        } else if profile != nil {
            source = .manual
        } else {
            source = .manual
        }

        return HealthSnapshot(
            collectedAt: Date(),
            source: source,
            stepCount: await stepCount,
            activeEnergyKCal: await activeEnergy,
            heightCm: resolvedHeight,
            weightKg: resolvedWeight,
            bmi: bmiValue,
            restingHeartRate: resolvedRHR,
            walkingHeartRateAverage: await walkingHR,
            peakHeartRate: await peakHR,
            heartRateRecovery: await recovery,
            vo2Max: await vo2,
            dataFreshnessHours: 0
        )
    }

    // ── Private helpers ──────────────────────────────────────────────────────

    private func emptySnapshot() -> HealthSnapshot {
        HealthSnapshot(
            collectedAt: Date(), source: .manual,
            stepCount: nil, activeEnergyKCal: nil,
            heightCm: nil, weightKg: nil, bmi: nil,
            restingHeartRate: nil, walkingHeartRateAverage: nil,
            peakHeartRate: nil, heartRateRecovery: nil,
            vo2Max: nil, dataFreshnessHours: nil
        )
    }

    private func latestQuantity(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit
    ) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }

        return await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(
                sampleType: type, predicate: nil,
                limit: 1, sortDescriptors: [sort]
            ) { _, samples, error in
                if let error { print("⚠️ HealthKit query error (\(identifier.rawValue)): \(error)") }
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: sample.quantity.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private func sumQuantity(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        forLastDays days: Int
    ) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }

        let predicate = quantityPredicate(forLastDays: days)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, error in
                if let error { print("⚠️ HealthKit sum error (\(identifier.rawValue)): \(error)") }
                continuation.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private func maxQuantity(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        forLastDays days: Int
    ) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }

        let predicate = quantityPredicate(forLastDays: days)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteMax
            ) { _, stats, error in
                if let error { print("⚠️ HealthKit max error (\(identifier.rawValue)): \(error)") }
                continuation.resume(returning: stats?.maximumQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private func quantityPredicate(forLastDays days: Int) -> NSPredicate {
        let end = Date()
        let start = Calendar.current.date(byAdding: .day, value: -days, to: end) ?? end
        return HKQuery.predicateForSamples(withStart: start, end: end)
    }
}

#else

@MainActor
final class HealthKitService: HealthDataProviding {
    var authorizationState: HealthAuthorizationState { .unavailable }
    func requestAuthorization() async -> Bool { false }
    func fetchLatestSnapshot(profile: UserProfileInput?) async -> HealthSnapshot {
        if let profile { return HealthSnapshot.manualFallback(from: profile) }
        return HealthSnapshot(
            collectedAt: Date(), source: .manual,
            stepCount: nil, activeEnergyKCal: nil,
            heightCm: nil, weightKg: nil, bmi: nil,
            restingHeartRate: nil, walkingHeartRateAverage: nil,
            peakHeartRate: nil, heartRateRecovery: nil,
            vo2Max: nil, dataFreshnessHours: nil
        )
    }
}

#endif
