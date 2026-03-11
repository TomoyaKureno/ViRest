import Foundation

enum BadgeType: String, Codable, CaseIterable, Identifiable {
    case firstCheckIn = "first_check_in"
    case streakThree = "streak_three"
    case consistencyTen = "consistency_ten"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .firstCheckIn: return "First Move"
        case .streakThree: return "3-Day Streak"
        case .consistencyTen: return "Consistency Builder"
        }
    }
}

struct BadgeEarned: Codable, Identifiable, Equatable {
    var id: UUID
    var type: BadgeType
    var earnedAt: Date

    init(id: UUID = UUID(), type: BadgeType, earnedAt: Date = Date()) {
        self.id = id
        self.type = type
        self.earnedAt = earnedAt
    }
}

enum ProgressionLevel: Int, Codable, CaseIterable {
    case level1 = 1
    case level2 = 2
    case level3 = 3
    case level4 = 4
    case level5 = 5
    case level6 = 6

    var title: String {
        switch self {
        case .level1: return "Starter"
        case .level2: return "Rhythm Rookie"
        case .level3: return "Cardio Climber"
        case .level4: return "Heart Defender"
        case .level5: return "Resting HR Hunter"
        case .level6: return "Pulse Master"
        }
    }

    var minSessions: Int {
        switch self {
        case .level1: return 0
        case .level2: return 10
        case .level3: return 18
        case .level4: return 30
        case .level5: return 45
        case .level6: return 65
        }
    }

    var nextTargetSessions: Int? {
        switch self {
        case .level1: return 10
        case .level2: return 18
        case .level3: return 30
        case .level4: return 45
        case .level5: return 65
        case .level6: return nil
        }
    }

    static func from(completedSessions: Int) -> ProgressionLevel {
        switch completedSessions {
        case 0..<10:
            return .level1
        case 10..<18:
            return .level2
        case 18..<30:
            return .level3
        case 30..<45:
            return .level4
        case 45..<65:
            return .level5
        default:
            return .level6
        }
    }
}

struct BadgeState: Codable, Equatable {
    var completedSessions: Int
    var currentStreak: Int
    var lastCheckInDate: Date?
    var level: ProgressionLevel
    var earnedBadges: [BadgeEarned]

    static let `default` = BadgeState(
        completedSessions: 0,
        currentStreak: 0,
        lastCheckInDate: nil,
        level: .level1,
        earnedBadges: []
    )
}

struct GamificationResult: Equatable {
    var updatedState: BadgeState
    var newlyEarnedBadges: [BadgeEarned]
    var appreciationMessage: String
}
