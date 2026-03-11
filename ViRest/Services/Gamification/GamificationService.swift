import Foundation

struct GamificationService: GamificationProviding {
    func evaluate(after checkIn: SessionCheckIn, current: BadgeState) -> GamificationResult {
        var updated = current
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
        updated.level = ProgressionLevel.from(completedSessions: updated.completedSessions)

        var newBadges: [BadgeEarned] = []
        let existingBadgeTypes = Set(updated.earnedBadges.map(\.type))

        if updated.completedSessions >= 1 && !existingBadgeTypes.contains(.firstCheckIn) {
            newBadges.append(BadgeEarned(type: .firstCheckIn))
        }

        if updated.currentStreak >= 3 && !existingBadgeTypes.contains(.streakThree) {
            newBadges.append(BadgeEarned(type: .streakThree))
        }

        if updated.completedSessions >= 10 && !existingBadgeTypes.contains(.consistencyTen) {
            newBadges.append(BadgeEarned(type: .consistencyTen))
        }

        updated.earnedBadges.append(contentsOf: newBadges)

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
            message = "Elite consistency unlocked. Maintain recovery and keep going."
        }

        return GamificationResult(updatedState: updated, newlyEarnedBadges: newBadges, appreciationMessage: message)
    }
}
