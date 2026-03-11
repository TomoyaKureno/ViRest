import Foundation

struct RuleBasedRecommendationEngine: RecommendationProviding {
    private let catalog: [SportCatalogItem]
    private let conservativeMaxRPE = 6

    init(catalog: [SportCatalogItem] = SportCatalog.items) {
        self.catalog = catalog
    }

    func recommend(request: RecommendationRequest) -> RecommendationResult {
        let safeCandidates = applySafetyGate(
            profile: request.userProfile,
            from: catalog
        )

        let candidates = safeCandidates.isEmpty ? fallbackCandidates(for: request.userProfile) : safeCandidates

        let scored = candidates.map { item in
            score(item: item, request: request)
        }
        .sorted { $0.score > $1.score }

        let topThree = Array(scored.prefix(3))
        let primary = topThree.first ?? fallbackRecommendation(for: request.userProfile)
        let alternatives = Array(topThree.dropFirst())

        let weeklyPlan = WeeklyPlan(
            weekStartDate: request.weekStartDate.startOfWeek(),
            goalFrequency: request.goalFrequency,
            primaryRecommendation: primary,
            alternatives: alternatives,
            sessions: generateSessions(
                primary: primary,
                request: request
            ),
            notes: [
                "Conservative safety policy enabled.",
                "Intensity progression is capped to safe RPE ranges."
            ]
        )

        return RecommendationResult(
            generatedAt: Date(),
            primary: primary,
            alternatives: alternatives,
            weeklyPlan: weeklyPlan
        )
    }

    private func applySafetyGate(profile: UserProfileInput, from items: [SportCatalogItem]) -> [SportCatalogItem] {
        items.filter { item in
            let conditionConflict = !Set(profile.healthConditions).isDisjoint(with: item.contraindicatedConditions)
            let injuryConflict = item.contraindicatedInjuries.contains(profile.injuryLimitation)

            // Conservative mode: remove risky activities as soon as one conflict is found.
            return !(conditionConflict || injuryConflict)
        }
    }

    private func score(item: SportCatalogItem, request: RecommendationRequest) -> SportRecommendation {
        let feasibility = scoreFeasibility(item: item, profile: request.userProfile)
        let preference = scorePreference(item: item, profile: request.userProfile)
        let cardio = scoreCardioImpact(
            item: item,
            snapshot: request.healthSnapshot,
            profile: request.userProfile
        )
        let total = feasibility * 0.4 + preference * 0.35 + cardio * 0.25

        let targetRPE = resolveTargetRPE(
            item: item,
            preference: request.userProfile.intensityPreference
        )
        let duration = mappedDuration(
            item: item,
            profile: request.userProfile
        )

        var reasons: [String] = []
        if feasibility >= 70 { reasons.append("Fits your weekly schedule and setup") }
        if preference >= 70 { reasons.append("Aligned with your activity and intensity preference") }
        if cardio >= 70 { reasons.append("Strong cardio fit to support resting HR improvement") }
        if isLowerImpactMatch(item: item, snapshot: request.healthSnapshot, profile: request.userProfile) {
            reasons.append("Lower-impact option matched to your current baseline")
        }
        if reasons.isEmpty { reasons.append("Safe and feasible under conservative mode") }

        return SportRecommendation(
            activity: item.activity,
            displayName: item.displayName,
            score: total,
            plannedDurationMinutes: duration,
            targetRPE: targetRPE,
            reasons: reasons
        )
    }

    private func scoreFeasibility(item: SportCatalogItem, profile: UserProfileInput) -> Double {
        var score = 100.0

        if profile.environment != .both && !item.allowedEnvironments.contains(profile.environment) {
            score -= 30
        }

        let available = Set(profile.equipments)
        let equipmentOptions = Set(item.requiredEquipments)
        let canDoWithoutEquipment = equipmentOptions.contains(.none)
        if !canDoWithoutEquipment && equipmentOptions.isDisjoint(with: available) {
            score -= 40
        }

        let targetMinutes = profile.sessionDuration.recommendedMinutes
        let durationLower = item.defaultDurationRangeMinutes.lowerBound
        let durationUpper = item.defaultDurationRangeMinutes.upperBound
        if targetMinutes < durationLower || targetMinutes > durationUpper {
            let distance = min(abs(targetMinutes - durationLower), abs(targetMinutes - durationUpper))
            score -= distance > 10 ? 20 : 10
        }

        if profile.daysPerWeek.targetSessions >= 4 && item.impactLevel == .high {
            score -= 10
        }

        return max(0, min(100, score))
    }

    private func scorePreference(item: SportCatalogItem, profile: UserProfileInput) -> Double {
        var score = 35.0

        if profile.enjoyableActivities.contains(item.activity) {
            score += 30
        }

        score += intensityCompatibilityScore(item: item, preference: profile.intensityPreference)
        score += socialCompatibilityScore(activity: item.activity, preference: profile.socialPreference)

        switch profile.consistency {
        case .quitEasily:
            if item.impactLevel == .low {
                score += 12
            } else if item.impactLevel == .high {
                score -= 6
            }
        case .somewhatConsistent:
            score += 5
        case .veryDisciplined:
            if item.impactLevel != .low {
                score += 8
            }
        }

        return max(0, min(100, score))
    }

    private func scoreCardioImpact(
        item: SportCatalogItem,
        snapshot: HealthSnapshot?,
        profile: UserProfileInput
    ) -> Double {
        var score = item.baseCardioScore
        let effectiveRestingHR = snapshot?.restingHeartRate ?? profile.restingHeartRateRange.midpoint

        if let rhr = effectiveRestingHR {
            if rhr >= 80 {
                switch item.impactLevel {
                case .low: score += 6
                case .moderate: score += 2
                case .high: score -= 3
                }
            } else if rhr <= 58, item.impactLevel == .high {
                score -= 3
            }
        }

        guard let snapshot else {
            return max(0, min(100, score))
        }

        if let vo2 = snapshot.vo2Max {
            if vo2 < 30 {
                if item.impactLevel != .high {
                    score += 4
                } else {
                    score += 1
                }
            } else if vo2 > 45 {
                score -= 2
            }
        }

        if let recovery = snapshot.heartRateRecovery, recovery < 20 {
            score += 5
        }

        if let walkingHR = snapshot.walkingHeartRateAverage, walkingHR > 110 {
            score += item.impactLevel == .low ? 4 : 2
        }

        if let freshness = snapshot.dataFreshnessHours, freshness > 72 {
            score -= 2
        }

        return max(0, min(100, score))
    }

    private func resolveTargetRPE(item: SportCatalogItem, preference: IntensityPreference) -> RPERange {
        let preferred = preference.targetRange
        let itemRange = RPERange(
            min: max(2, item.minRPE),
            max: min(item.maxRPE, conservativeMaxRPE)
        )
        let overlapMin = max(preferred.min, itemRange.min)
        let overlapMax = min(preferred.max, itemRange.max)

        if overlapMin <= overlapMax {
            return RPERange(min: overlapMin, max: overlapMax)
        }

        if preferred.max < itemRange.min {
            let resolvedMax = min(itemRange.min + 1, itemRange.max)
            return RPERange(min: itemRange.min, max: resolvedMax)
        }

        let resolvedMin = max(itemRange.min, itemRange.max - 1)
        return RPERange(min: resolvedMin, max: itemRange.max)
    }

    private func mappedDuration(item: SportCatalogItem, profile: UserProfileInput) -> Int {
        let preferred = profile.sessionDuration.recommendedMinutes
        return min(max(preferred, item.defaultDurationRangeMinutes.lowerBound), item.defaultDurationRangeMinutes.upperBound)
    }

    private func generateSessions(primary: SportRecommendation, request: RecommendationRequest) -> [SessionPlan] {
        let capByUserAvailability = request.userProfile.daysPerWeek.targetSessions
        let requested = request.goalFrequency.sessionsPerWeek
        let totalSessions = max(1, min(requested, capByUserAvailability))

        return (1...totalSessions).map { number in
            SessionPlan(
                sessionNumber: number,
                activity: primary.activity,
                preferredTime: request.userProfile.preferredTime,
                plannedDurationMinutes: primary.plannedDurationMinutes,
                targetRPE: primary.targetRPE
            )
        }
    }

    private func fallbackRecommendation(for profile: UserProfileInput) -> SportRecommendation {
        let fallbackDuration = min(max(profile.sessionDuration.recommendedMinutes, 20), 50)
        return SportRecommendation(
            activity: .walking,
            displayName: "Brisk Walking",
            score: 60,
            plannedDurationMinutes: fallbackDuration,
            targetRPE: RPERange(min: 2, max: 4),
            reasons: ["Safe fallback while preserving cardio stimulus"]
        )
    }

    private func fallbackCandidates(for profile: UserProfileInput) -> [SportCatalogItem] {
        let conservative = catalog.filter {
            [.walking, .stretching, .yoga, .lowImpactAerobics].contains($0.activity)
        }
        let safe = applySafetyGate(profile: profile, from: conservative)
        if !safe.isEmpty {
            return safe
        }

        return catalog.filter { $0.activity == .walking }
    }

    private func intensityCompatibilityScore(item: SportCatalogItem, preference: IntensityPreference) -> Double {
        let preferred = preference.targetRange
        let itemMin = max(2, item.minRPE)
        let itemMax = min(item.maxRPE, conservativeMaxRPE)
        let overlapMin = max(preferred.min, itemMin)
        let overlapMax = min(preferred.max, itemMax)

        if overlapMin <= overlapMax {
            return 20
        }

        if preferred.max < itemMin {
            return 10
        }

        return 8
    }

    private func socialCompatibilityScore(activity: ActivityType, preference: SocialPreference) -> Double {
        guard preference != .either else { return 12 }

        let modes = socialModes(for: activity)
        return modes.contains(preference) ? 15 : 4
    }

    private func socialModes(for activity: ActivityType) -> Set<SocialPreference> {
        switch activity {
        case .dancing:
            return [.withFriends, .classes, .solo]
        case .hiking:
            return [.withFriends, .solo]
        case .badminton, .tennisDoubles:
            return [.withFriends]
        case .lowImpactAerobics, .aquaAerobics, .indoorCycling, .yoga:
            return [.classes, .solo]
        default:
            return [.solo]
        }
    }

    private func isLowerImpactMatch(
        item: SportCatalogItem,
        snapshot: HealthSnapshot?,
        profile: UserProfileInput
    ) -> Bool {
        guard item.impactLevel != .high else { return false }
        let restingHR = snapshot?.restingHeartRate ?? profile.restingHeartRateRange.midpoint
        guard let restingHR else { return false }
        return restingHR >= 80
    }
}
