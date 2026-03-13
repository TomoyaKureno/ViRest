import Foundation

struct SportsJsonRoot: Decodable {
    var exercises: [SportsJsonExercise]
}

struct SportsJsonExercise: Decodable {
    var name: String
    var environment: String
    var impactLevel: String?
    var equipment: [String]
    var rhrBands: [SportsJsonRhrBand]
}

struct SportsJsonRhrBand: Decodable {
    var rhrBand: String
    var bmiRules: [SportsJsonBmiRule]
}

struct SportsJsonBmiRule: Decodable {
    var bmiCategory: String
    var keyCautions: [String]
    var contraindications: [String]
    var durationPrescription: SportsJsonDurationPrescription
    var weeklyFrequencyPrescription: SportsJsonFrequencyPrescription
}

struct SportsJsonDurationPrescription: Decodable {
    var isProgression: Bool
    var standardPhase: SportsJsonDurationStandard?
    // JSON uses "startPhase" / "targetPhase" for progressions
    var startPhase: SportsJsonDurationStandard?
    var targetPhase: SportsJsonDurationStandard?
}

struct SportsJsonDurationStandard: Decodable {
    var minMinutes: Int
    var maxMinutes: Int
}

struct SportsJsonFrequencyPrescription: Decodable {
    var isProgression: Bool
    var standardPhase: SportsJsonFrequencyStandard?
    // JSON uses "startPhase" / "targetPhase" for progressions
    var startPhase: SportsJsonFrequencyStandard?
    var targetPhase: SportsJsonFrequencyStandard?
}

struct SportsJsonFrequencyStandard: Decodable {
    var minDaysPerWeek: Int
    var maxDaysPerWeek: Int
}
