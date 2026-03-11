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

    func requestAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else {
            return false
        }

        let quantityTypes = [
            HKObjectType.quantityType(forIdentifier: .stepCount),
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned),
            HKObjectType.quantityType(forIdentifier: .height),
            HKObjectType.quantityType(forIdentifier: .bodyMass),
            HKObjectType.quantityType(forIdentifier: .restingHeartRate),
            HKObjectType.quantityType(forIdentifier: .walkingHeartRateAverage),
            HKObjectType.quantityType(forIdentifier: .heartRate),
            HKObjectType.quantityType(forIdentifier: .vo2Max),
            HKObjectType.quantityType(forIdentifier: .heartRateRecoveryOneMinute)
        ].compactMap { $0 }
        let characteristicTypes: [HKObjectType] = [
            HKObjectType.characteristicType(forIdentifier: .dateOfBirth),
            HKObjectType.characteristicType(forIdentifier: .biologicalSex)
        ]
        .compactMap { $0 as HKObjectType? }
        let readTypes = Set<HKObjectType>(quantityTypes.map { $0 as HKObjectType } + characteristicTypes)

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

        async let stepCount = sumQuantity(identifier: .stepCount, unit: .count(), forLastDays: 7)
        async let activeEnergy = sumQuantity(identifier: .activeEnergyBurned, unit: .kilocalorie(), forLastDays: 7)
        async let heightMeters = latestQuantity(identifier: .height, unit: .meter())
        async let weightKg = latestQuantity(identifier: .bodyMass, unit: .gramUnit(with: .kilo))
        async let restingHR = latestQuantity(identifier: .restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()))
        async let walkingHR = latestQuantity(identifier: .walkingHeartRateAverage, unit: HKUnit.count().unitDivided(by: .minute()))
        async let peakHR = maxQuantity(identifier: .heartRate, unit: HKUnit.count().unitDivided(by: .minute()), forLastDays: 7)
        async let vo2 = latestQuantity(identifier: .vo2Max, unit: HKUnit(from: "ml/kg*min"))
        async let recovery = latestQuantity(identifier: .heartRateRecoveryOneMinute, unit: HKUnit.count().unitDivided(by: .minute()))

        let collectedAt = Date()
        let ageYearsValue = readAgeYears()
        let biologicalGenderValue = readBiologicalGender()
        let stepCountValue = await stepCount
        let activeEnergyValue = await activeEnergy
        let heightCmValue = (await heightMeters).map { $0 * 100 }
        let weightKgValue = await weightKg
        let restingHRValue = await restingHR
        let walkingHRValue = await walkingHR
        let peakHRValue = await peakHR
        let recoveryValue = await recovery
        let vo2Value = await vo2

        let hasHealthData = hasAnyHealthData(
            ageYears: ageYearsValue,
            biologicalGender: biologicalGenderValue,
            stepCount: stepCountValue,
            activeEnergy: activeEnergyValue,
            heightCm: heightCmValue,
            weightKg: weightKgValue,
            restingHeartRate: restingHRValue,
            walkingHeartRateAverage: walkingHRValue,
            peakHeartRate: peakHRValue,
            heartRateRecovery: recoveryValue,
            vo2Max: vo2Value
        )

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

        let manualResting = profile?.restingHeartRateRange.midpoint
        let resolvedResting = restingHRValue ?? manualResting
        let usedManualFallbackValues = profile != nil && (heightCmValue == nil || weightKgValue == nil || restingHRValue == nil)
        let source: HealthDataSource = usedManualFallbackValues ? .mixed : .healthKit

        return HealthSnapshot(
            collectedAt: collectedAt,
            source: source,
            ageYears: ageYearsValue ?? profile?.age,
            biologicalGender: biologicalGenderValue ?? profile?.gender,
            stepCount: stepCountValue,
            activeEnergyKCal: activeEnergyValue,
            heightCm: heightCmValue ?? profile?.heightCm,
            weightKg: weightKgValue ?? profile?.weightKg,
            bmi: bmiValue,
            restingHeartRate: resolvedResting,
            walkingHeartRateAverage: walkingHRValue,
            peakHeartRate: peakHRValue,
            heartRateRecovery: recoveryValue,
            vo2Max: vo2Value,
            dataFreshnessHours: 0
        )
    }

    private func hasAnyHealthData(
        ageYears: Int?,
        biologicalGender: Gender?,
        stepCount: Double?,
        activeEnergy: Double?,
        heightCm: Double?,
        weightKg: Double?,
        restingHeartRate: Double?,
        walkingHeartRateAverage: Double?,
        peakHeartRate: Double?,
        heartRateRecovery: Double?,
        vo2Max: Double?
    ) -> Bool {
        ageYears != nil ||
        biologicalGender != nil ||
        stepCount != nil ||
        activeEnergy != nil ||
        heightCm != nil ||
        weightKg != nil ||
        restingHeartRate != nil ||
        walkingHeartRateAverage != nil ||
        peakHeartRate != nil ||
        heartRateRecovery != nil ||
        vo2Max != nil
    }

    private func readAgeYears() -> Int? {
        do {
            let components = try store.dateOfBirthComponents()
            guard let dobDate = Calendar.current.date(from: components) else { return nil }
            let years = Calendar.current.dateComponents([.year], from: dobDate, to: Date()).year
            guard let years, years > 0 else { return nil }
            return years
        } catch {
            return nil
        }
    }

    private func readBiologicalGender() -> Gender? {
        do {
            let biologicalSex = try store.biologicalSex().biologicalSex
            switch biologicalSex {
            case .female:
                return .female
            case .male:
                return .male
            case .other:
                return .nonBinary
            case .notSet:
                return nil
            @unknown default:
                return nil
            }
        } catch {
            return nil
        }
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

    private func sumQuantity(identifier: HKQuantityTypeIdentifier, unit: HKUnit, forLastDays days: Int) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            return nil
        }

        let predicate = quantityPredicate(forLastDays: days)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, stats, _ in
                continuation.resume(returning: stats?.sumQuantity()?.doubleValue(for: unit))
            }
            store.execute(query)
        }
    }

    private func maxQuantity(identifier: HKQuantityTypeIdentifier, unit: HKUnit, forLastDays days: Int) async -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            return nil
        }

        let predicate = quantityPredicate(forLastDays: days)
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteMax) { _, stats, _ in
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
