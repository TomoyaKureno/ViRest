import Foundation

// Maps RestingHeartRateRange to the exact band strings in sports.json
// Note: sports.json uses en-dash (–) not hyphen (-)
extension RestingHeartRateRange {
    var sportsJsonBand: String {
        switch self {
        case .below50:    return "<= 60 bpm"
        case .from50To60: return "<= 60 bpm"
        case .from60To70: return "61 – 75 bpm"
        case .from71To80: return "61 – 75 bpm"
        case .from81To90: return "76 – 90 bpm"
        case .above90:    return "> 90 bpm"
        case .unknown:    return "61 – 75 bpm"  // default to moderate band
        }
    }
}

// Derive BMI category string matching sports.json bmiCategory values
struct BMICalculator {
    static func category(heightCm: Double?, weightKg: Double?) -> String {
        guard let h = heightCm, let w = weightKg, h > 0, w > 0 else {
            return "Any BMI"  // no data — use broadest fallback
        }
        let bmi = w / ((h / 100) * (h / 100))
        switch bmi {
        case ..<25:   return "Normal"
        case 25..<30: return "Overweight"
        default:      return "Obese"
        }
    }
}

struct SportPrescription {
    var sportName: String
    var minDurationMinutes: Int
    var maxDurationMinutes: Int
    var minDaysPerWeek: Int
    var maxDaysPerWeek: Int
    var keyCautions: [String]
    var contraindications: [String]
}

final class SportsCatalogLoader {
    static let shared = SportsCatalogLoader()
    private(set) var exercises: [SportsJsonExercise] = []

    init() { load() }

    private func load() {
        guard let url = Bundle.main.url(forResource: "sports", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("⚠️ sports.json not found in bundle")
            return
        }
        do {
            let parsed = try JSONDecoder().decode(SportsJsonRoot.self, from: data)
            self.exercises = parsed.exercises
            print("✅ Loaded \(exercises.count) exercises from sports.json")
        } catch {
            print("⚠️ Failed to decode sports.json: \(error)")
        }
    }

    func prescription(
        for sportName: String,
        rhrBand: String,
        bmiCategory: String
    ) -> SportPrescription? {
        guard let exercise = exercises.first(where: { $0.name == sportName }) else {
            return nil
        }

        // Find matching RHR band, fallback to first available
        let band = exercise.rhrBands.first { $0.rhrBand == rhrBand }
            ?? exercise.rhrBands.first

        guard let band else { return nil }

        // BMI rule lookup with 3-level fallback:
        // 1. Exact match (e.g. "Normal")
        // 2. "Any BMI" rule
        // 3. First rule available
        let rule = band.bmiRules.first { $0.bmiCategory == bmiCategory }
            ?? band.bmiRules.first { $0.bmiCategory == "Any BMI" }
            ?? band.bmiRules.first

        guard let rule else { return nil }

        // Duration — handle both standard and progression formats
        let dur = rule.durationPrescription
        let durMin: Int
        let durMax: Int

        if dur.isProgression {
            // Use startPhase as the initial target
            durMin = dur.startPhase?.minMinutes ?? dur.standardPhase?.minMinutes ?? 20
            durMax = dur.startPhase?.maxMinutes ?? dur.standardPhase?.maxMinutes ?? 30
        } else {
            durMin = dur.standardPhase?.minMinutes ?? 20
            durMax = dur.standardPhase?.maxMinutes ?? 30
        }

        // Frequency — handle both standard and progression formats
        let freq = rule.weeklyFrequencyPrescription
        let freqMin: Int
        let freqMax: Int

        if freq.isProgression {
            freqMin = freq.startPhase?.minDaysPerWeek ?? freq.standardPhase?.minDaysPerWeek ?? 2
            freqMax = freq.startPhase?.maxDaysPerWeek ?? freq.standardPhase?.maxDaysPerWeek ?? 3
        } else {
            freqMin = freq.standardPhase?.minDaysPerWeek ?? 2
            freqMax = freq.standardPhase?.maxDaysPerWeek ?? 3
        }

        return SportPrescription(
            sportName: exercise.name,
            minDurationMinutes: durMin,
            maxDurationMinutes: durMax,
            minDaysPerWeek: freqMin,
            maxDaysPerWeek: freqMax,
            keyCautions: rule.keyCautions,
            contraindications: rule.contraindications
        )
    }
}
