import Foundation

struct GamificationService: GamificationProviding {
    func evaluate(after checkIn: SessionCheckIn, current: BadgeState) -> GamificationResult {
        var updated = current
        _ = updated.normalizeRandomCriteriaIfNeeded()
        updated.completedSessions += 1

        if let last = updated.lastCheckInDate {
            if checkIn.checkInDate.isSameDay(as: last) {
                // Keep streak unchanged if multiple check-ins happen in the same day.
            } else if last.isYesterday(relativeTo: checkIn.checkInDate) {
                updated.currentStreak += 1
            } else {
                updated.currentStreak = 1
            }
        } else {
            updated.currentStreak = 1
        }

        updated.lastCheckInDate = checkIn.checkInDate
        if checkIn.painLevel == .noPain {
            updated.painFreeSessions += 1
        }
        let activityToken = normalizedToken(checkIn.activity.rawValue)
        if !updated.uniqueActivityTokens.contains(activityToken) {
            updated.uniqueActivityTokens.append(activityToken)
            updated.uniqueActivityTokens.sort()
        }
        updated.level = ProgressionLevel.from(completedSessions: updated.completedSessions)

        var newBadges: [BadgeEarned] = []
        let existingBadgeTypes = Set(updated.earnedBadges.map(\.type))
        let sortedCriteria = updated.randomCriteria.sorted {
            $0.badgeType.rawValue < $1.badgeType.rawValue
        }

        for criterion in sortedCriteria {
            guard !existingBadgeTypes.contains(criterion.badgeType) else { continue }
            let currentMetric = updated.metricValue(for: criterion.kind)
            if currentMetric >= criterion.targetValue {
                newBadges.append(BadgeEarned(type: criterion.badgeType))
            }
        }

        updated.earnedBadges.append(contentsOf: newBadges)
        updated.earnedBadges.sort { $0.earnedAt < $1.earnedAt }

        let message: String
        switch updated.level {
        case .level1:
            message = "Nice work. You are building a sustainable routine."
        case .level2:
            message = "Great start. Keep stacking sessions to build rhythm."
        case .level3:
            message = "Strong momentum. Your cardio adaptation is getting better."
        case .level4:
            message = "Solid progress. Your weekly consistency is now reliable."
        case .level5:
            message = "Excellent commitment. You are close to top-tier consistency."
        case .level6:
            message = "Pulse-level consistency unlocked. Keep this pace steady."
        case .level7:
            message = "Endurance is climbing fast. Your routine is now very resilient."
        case .level8:
            message = "Outstanding discipline. You are operating at high consistency."
        case .level9:
            message = "You are in peak performer territory. Keep recovery in balance."
        case .level10:
            message = "Legend status unlocked. Maintain form, sleep, and steady progress."
        }

        return GamificationResult(updatedState: updated, newlyEarnedBadges: newBadges, appreciationMessage: message)
    }

    private func normalizedToken(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "[^a-z0-9]+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
            .lowercased()
    }
}
