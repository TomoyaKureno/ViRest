import Foundation

enum Gender: String, Codable, CaseIterable, Identifiable {
    case female
    case male
    case nonBinary = "non_binary"
    case preferNotToSay = "prefer_not_to_say"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .female: return "Female"
        case .male: return "Male"
        case .nonBinary: return "Non-binary"
        case .preferNotToSay: return "Prefer not to say"
        }
    }
}

enum RestingHeartRateRange: String, Codable, CaseIterable, Identifiable {
    case below50 = "below_50"
    case from50To60 = "50_60"
    case from60To70 = "60_70"
    case from71To80 = "71_80"
    case from81To90 = "81_90"
    case above90 = "above_90"
    case unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .below50: return "<50 bpm"
        case .from50To60: return "50-60 bpm"
        case .from60To70: return "60-70 bpm"
        case .from71To80: return "71-80 bpm"
        case .from81To90: return "81-90 bpm"
        case .above90: return "90+ bpm"
        case .unknown: return "I don't know"
        }
    }

    var midpoint: Double? {
        switch self {
        case .below50: return 48
        case .from50To60: return 55
        case .from60To70: return 65
        case .from71To80: return 75
        case .from81To90: return 85
        case .above90: return 95
        case .unknown: return nil
        }
    }
}

enum HealthCondition: String, Codable, CaseIterable, Identifiable {
    case highBloodPressure = "high_blood_pressure"
    case heartDisease = "heart_disease"
    case arrhythmia
    case highCholesterol = "high_cholesterol"
    case jointProblems = "joint_problems"
    case backPain = "back_pain"
    case asthma
    case chronicRespiratoryCondition = "chronic_respiratory_condition"
    case type2Diabetes = "type2_diabetes"
    case obesity
    case postSurgeryRecovery = "post_surgery_recovery"
    case otherMedicalCondition = "other_medical_condition"
    case none

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .highBloodPressure: return "High blood pressure"
        case .heartDisease: return "Heart disease"
        case .arrhythmia: return "Arrhythmia / irregular heartbeat"
        case .highCholesterol: return "High cholesterol"
        case .jointProblems: return "Joint problems"
        case .backPain: return "Back pain"
        case .asthma: return "Asthma"
        case .chronicRespiratoryCondition: return "Chronic respiratory condition"
        case .type2Diabetes: return "Type 2 diabetes"
        case .obesity: return "Obesity"
        case .postSurgeryRecovery: return "Post-surgery recovery"
        case .otherMedicalCondition: return "Other medical condition"
        case .none: return "None"
        }
    }
}

enum InjuryLimitation: String, Codable, CaseIterable, Identifiable {
    case noLimitation = "no_limitation"
    case kneePain = "knee_pain"
    case backPain = "back_pain"
    case shoulderIssue = "shoulder_issue"
    case multipleIssues = "multiple_issues"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .noLimitation: return "No limitation"
        case .kneePain: return "Knee pain"
        case .backPain: return "Back pain"
        case .shoulderIssue: return "Shoulder issue"
        case .multipleIssues: return "Multiple issues"
        }
    }
}

enum SessionDurationOption: String, Codable, CaseIterable, Identifiable {
    case fiveToTen = "5_10"
    case tenToTwenty = "10_20"
    case twentyToThirty = "20_30"
    case thirtyToFortyFive = "30_45"
    case aboveFortyFive = "45_plus"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fiveToTen: return "5-10 minutes"
        case .tenToTwenty: return "10-20 minutes"
        case .twentyToThirty: return "20-30 minutes"
        case .thirtyToFortyFive: return "30-45 minutes"
        case .aboveFortyFive: return "45 minutes"
        }
    }

    var recommendedMinutes: Int {
        switch self {
        case .fiveToTen: return 10
        case .tenToTwenty: return 20
        case .twentyToThirty: return 30
        case .thirtyToFortyFive: return 45
        case .aboveFortyFive: return 45
        }
    }
}

enum DaysPerWeekAvailability: String, Codable, CaseIterable, Identifiable {
    case oneToTwo = "1_2"
    case three
    case fourToFive = "4_5"
    case daily

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .oneToTwo: return "1-2 days"
        case .three: return "3 days"
        case .fourToFive: return "4-5 days"
        case .daily: return "Daily"
        }
    }

    var targetSessions: Int {
        switch self {
        case .oneToTwo: return 2
        case .three: return 3
        case .fourToFive: return 5
        case .daily: return 7
        }
    }
}

enum PreferredTime: String, Codable, CaseIterable, Identifiable {
    case morning
    case lunchBreak = "lunch_break"
    case evening
    case noPreference = "no_preference"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .morning: return "Morning"
        case .lunchBreak: return "Lunch break"
        case .evening: return "Evening"
        case .noPreference: return "No preference"
        }
    }
}

enum SportEnvironment: String, Codable, CaseIterable, Identifiable {
    case indoor
    case outdoor
    case both

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .indoor: return "Indoor"
        case .outdoor: return "Outdoor"
        case .both: return "Both"
        }
    }
}

enum Equipment: String, Codable, CaseIterable, Identifiable {
    case none
    case yogaMat = "yoga_mat"
    case resistanceBands = "resistance_bands"
    case dumbbells
    case kettlebell
    case ankleWeights = "ankle_weights"
    case bicycle
    case treadmill
    case tennisRacket = "tennis_racket"
    case badmintonRacket = "badminton_racket"
    case jumpRope = "jump_rope"
    case rowingMachine = "rowing_machine"
    case ellipticalMachine = "elliptical_machine"
    case swimmingPoolAccess = "swimming_pool_access"
    case sportsCourtAccess = "sports_court_access"
    case stairsOrHillAccess = "stairs_or_hill_access"
    case gymMembership = "gym_membership"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "None"
        case .yogaMat: return "Yoga mat"
        case .resistanceBands: return "Resistance bands"
        case .dumbbells: return "Dumbbells"
        case .kettlebell: return "Kettlebell"
        case .ankleWeights: return "Ankle weights"
        case .bicycle: return "Bicycle"
        case .treadmill: return "Treadmill"
        case .tennisRacket: return "Tennis racket"
        case .badmintonRacket: return "Badminton racket"
        case .jumpRope: return "Jump rope"
        case .rowingMachine: return "Rowing machine"
        case .ellipticalMachine: return "Elliptical machine"
        case .swimmingPoolAccess: return "Swimming pool access"
        case .sportsCourtAccess: return "Sports court access"
        case .stairsOrHillAccess: return "Stairs / hill access"
        case .gymMembership: return "Gym membership"
        }
    }
}

enum ActivityType: String, Codable, CaseIterable, Identifiable {
    case walking
    case inclineWalking = "incline_walking"
    case nordicWalking = "nordic_walking"
    case runWalkInterval = "run_walk_interval"
    case cycling
    case indoorCycling = "indoor_cycling"
    case swimming
    case aquaAerobics = "aqua_aerobics"
    case stairClimbing = "stair_climbing"
    case ellipticalTrainer = "elliptical_trainer"
    case rowing
    case lowImpactAerobics = "low_impact_aerobics"
    case yoga
    case stretching
    case dancing
    case bodyweightExercise = "bodyweight_exercise"
    case hiking
    case badminton
    case tennisDoubles = "tennis_doubles"
    case lightJogging = "light_jogging"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .walking: return "Brisk walking"
        case .inclineWalking: return "Incline walking"
        case .nordicWalking: return "Nordic walking"
        case .runWalkInterval: return "Run-walk interval"
        case .cycling: return "Outdoor cycling"
        case .indoorCycling: return "Indoor cycling"
        case .swimming: return "Swimming"
        case .aquaAerobics: return "Aqua aerobics"
        case .stairClimbing: return "Stair climbing"
        case .ellipticalTrainer: return "Elliptical trainer"
        case .rowing: return "Rowing ergometer"
        case .lowImpactAerobics: return "Low-impact aerobics"
        case .yoga: return "Vinyasa yoga"
        case .stretching: return "Dynamic stretching flow"
        case .dancing: return "Dance cardio"
        case .bodyweightExercise: return "Bodyweight cardio circuit"
        case .hiking: return "Hiking"
        case .badminton: return "Badminton (recreational)"
        case .tennisDoubles: return "Tennis doubles"
        case .lightJogging: return "Light jogging"
        }
    }
}

enum IntensityPreference: String, Codable, CaseIterable, Identifiable {
    case veryLight = "very_light"
    case light
    case moderate
    case challenging

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .veryLight: return "Very light"
        case .light: return "Light"
        case .moderate: return "Moderate"
        case .challenging: return "Challenging"
        }
    }

    var targetRange: RPERange {
        switch self {
        case .veryLight: return RPERange(min: 2, max: 3)
        case .light: return RPERange(min: 3, max: 4)
        case .moderate: return RPERange(min: 4, max: 6)
        case .challenging: return RPERange(min: 5, max: 6)
        }
    }
}

enum SocialPreference: String, Codable, CaseIterable, Identifiable {
    case solo
    case withFriends = "with_friends"
    case classes
    case either

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .solo: return "Solo"
        case .withFriends: return "With friends"
        case .classes: return "Classes"
        case .either: return "Either"
        }
    }
}

enum ConsistencyLevel: String, Codable, CaseIterable, Identifiable {
    case quitEasily = "quit_easily"
    case somewhatConsistent = "somewhat_consistent"
    case veryDisciplined = "very_disciplined"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .quitEasily: return "I quit easily"
        case .somewhatConsistent: return "Somewhat consistent"
        case .veryDisciplined: return "Very disciplined"
        }
    }
}

struct UserProfileInput: Codable, Identifiable, Equatable {
    var id: UUID
    var fullName: String
    var age: Int?
    var gender: Gender?
    var heightCm: Double?
    var weightKg: Double?
    var restingHeartRateRange: RestingHeartRateRange
    var healthConditions: [HealthCondition]
    var injuryLimitation: InjuryLimitation
    var sessionDuration: SessionDurationOption
    var daysPerWeek: DaysPerWeekAvailability
    var preferredTime: PreferredTime
    var environment: SportEnvironment
    var equipments: [Equipment]
    var enjoyableActivities: [ActivityType]
    var intensityPreference: IntensityPreference
    var socialPreference: SocialPreference
    var consistency: ConsistencyLevel
    var targetRestingHeartRateRange: RestingHeartRateRange
    var acceptedDisclaimer: Bool
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        fullName: String = "",
        age: Int? = nil,
        gender: Gender? = nil,
        heightCm: Double? = nil,
        weightKg: Double? = nil,
        restingHeartRateRange: RestingHeartRateRange = .unknown,
        healthConditions: [HealthCondition] = [.none],
        injuryLimitation: InjuryLimitation = .noLimitation,
        sessionDuration: SessionDurationOption = .twentyToThirty,
        daysPerWeek: DaysPerWeekAvailability = .three,
        preferredTime: PreferredTime = .noPreference,
        environment: SportEnvironment = .both,
        equipments: [Equipment] = [.none],
        enjoyableActivities: [ActivityType] = [.walking],
        intensityPreference: IntensityPreference = .light,
        socialPreference: SocialPreference = .either,
        consistency: ConsistencyLevel = .somewhatConsistent,
        targetRestingHeartRateRange: RestingHeartRateRange = .from60To70,
        acceptedDisclaimer: Bool = false,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.fullName = fullName
        self.age = age
        self.gender = gender
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.restingHeartRateRange = restingHeartRateRange
        self.healthConditions = healthConditions
        self.injuryLimitation = injuryLimitation
        self.sessionDuration = sessionDuration
        self.daysPerWeek = daysPerWeek
        self.preferredTime = preferredTime
        self.environment = environment
        self.equipments = equipments
        self.enjoyableActivities = enjoyableActivities
        self.intensityPreference = intensityPreference
        self.socialPreference = socialPreference
        self.consistency = consistency
        self.targetRestingHeartRateRange = targetRestingHeartRateRange
        self.acceptedDisclaimer = acceptedDisclaimer
        self.updatedAt = updatedAt
    }
}
