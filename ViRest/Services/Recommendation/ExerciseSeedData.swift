import Foundation

struct ExerciseSeedCatalog: Decodable {
    let rhrBands: [String]
    let bmiCategories: [String]
    let environmentOptions: [String]
    let healthConcernContraindicationOptions: [String]
    let exercises: [ExerciseSeedExercise]
}

struct ExerciseSeedExercise: Decodable {
    let exercise: String
    let environment: String
    let impactLevel: String
    let equipment: [String]
    let rhrBands: [ExerciseSeedRHRBandRule]

    var id: String {
        exercise
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
    }
}

struct ExerciseSeedRHRBandRule: Decodable {
    let rhrBand: String
    let bmiRules: [ExerciseSeedBMIRule]
}

struct ExerciseSeedBMIRule: Decodable {
    let bmiCategory: String
    let keyCautions: [String]
    let contraindications: [String]
    let durationPrescription: ExerciseSeedDurationPrescription
    let weeklyFrequencyPrescription: ExerciseSeedWeeklyFrequencyPrescription
}

struct ExerciseSeedDurationPrescription: Decodable {
    let isProgression: Bool
    let standardPhase: ExerciseSeedDurationPhase?
    let startPhase: ExerciseSeedDurationPhase?
    let targetPhase: ExerciseSeedDurationPhase?

    var entryRange: ClosedRange<Int>? {
        (startPhase ?? standardPhase ?? targetPhase)?.range
    }

    var targetRange: ClosedRange<Int>? {
        (standardPhase ?? targetPhase ?? startPhase)?.range
    }
}

struct ExerciseSeedDurationPhase: Decodable {
    let minMinutes: Int
    let maxMinutes: Int

    var range: ClosedRange<Int> {
        minMinutes...maxMinutes
    }
}

struct ExerciseSeedWeeklyFrequencyPrescription: Decodable {
    let isProgression: Bool
    let standardPhase: ExerciseSeedWeeklyFrequencyPhase?
    let startPhase: ExerciseSeedWeeklyFrequencyPhase?
    let targetPhase: ExerciseSeedWeeklyFrequencyPhase?

    var entryRange: ClosedRange<Int>? {
        (startPhase ?? standardPhase ?? targetPhase)?.range
    }

    var targetRange: ClosedRange<Int>? {
        (standardPhase ?? targetPhase ?? startPhase)?.range
    }
}

struct ExerciseSeedWeeklyFrequencyPhase: Decodable {
    let minDaysPerWeek: Int
    let maxDaysPerWeek: Int

    var range: ClosedRange<Int> {
        minDaysPerWeek...maxDaysPerWeek
    }
}

enum ExerciseSeedLoader {
    static func loadCatalog() -> ExerciseSeedCatalog? {
        for url in candidateURLs() {
            guard let data = try? Data(contentsOf: url) else { continue }
            let decoder = JSONDecoder()
            if let catalog = try? decoder.decode(ExerciseSeedCatalog.self, from: data),
               !catalog.exercises.isEmpty {
                return catalog
            }
        }
        return nil
    }

    static func loadExercises() -> [ExerciseSeedExercise] {
        loadCatalog()?.exercises ?? []
    }

    private static func candidateURLs() -> [URL] {
        var urls: [URL] = []

        if let bundled = Bundle.main.url(forResource: "exercise_matrix_v4_flat", withExtension: "json") {
            urls.append(bundled)
        }

        if let bundledOriginal = Bundle.main.url(
            forResource: "cleaned_exercise_matrix_grouped_v4_flat",
            withExtension: "json"
        ) {
            urls.append(bundledOriginal)
        }

        let cwdURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("ViRest/Resources/exercise_matrix_v4_flat.json")
        urls.append(cwdURL)

        let downloadsURL = URL(fileURLWithPath: "/Users/tomoya/Downloads/cleaned_exercise_matrix_grouped_v4_flat.json")
        urls.append(downloadsURL)

        return urls
    }
}
