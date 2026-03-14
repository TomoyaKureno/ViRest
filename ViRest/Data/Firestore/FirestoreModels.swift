//
//  FirestoreModels.swift
//  ViRest
//
//  Created by Joshua Valentine Manik on 13/03/26.
//

import Foundation
import FirebaseFirestore

// Maps to the 'users' Firestore collection
struct FirestoreUser: Codable {
    @DocumentID var documentId: String?
    var id: String
    var email: String?
    var displayName: String?
    var age: Int?
    var restingHeartRate: Int?
    var targetRestingHeartRate: Int?
    var currentTitleId: String
    var totalActionsCompleted: Int
    var recommendationParameters: [String: String]
    var createdAt: Date
    var lastActiveAt: Date

    // Nested sport plan — stored as subcollection or embedded
    // For simplicity we embed as a field
    var sportPlan: FirestoreSportPlan?

    init(from authUser: AuthUser) {
        self.id = authUser.id
        self.email = authUser.email
        self.displayName = authUser.displayName
        self.currentTitleId = ""
        self.totalActionsCompleted = 0
        self.recommendationParameters = [:]
        self.createdAt = Date()
        self.lastActiveAt = Date()
    }
}

// Holds the three recommended sports and their weekly targets
struct FirestoreSportPlan: Codable {
    var generatedAt: Date
    var sports: [FirestoreSportEntry]  // exactly 3

    private enum CodingKeys: String, CodingKey {
        case generatedAt
        case weekStartDate
        case sports
    }

    init(generatedAt: Date, sports: [FirestoreSportEntry]) {
        self.generatedAt = generatedAt
        self.sports = sports
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.generatedAt =
            try container.decodeIfPresent(Date.self, forKey: .generatedAt)
            ?? container.decodeIfPresent(Date.self, forKey: .weekStartDate)
            ?? Date()
        self.sports = try container.decodeIfPresent([FirestoreSportEntry].self, forKey: .sports) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(generatedAt, forKey: .generatedAt)
        try container.encode(sports, forKey: .sports)
    }

    func programWeekIndex(at date: Date = Date()) -> Int {
        let calendar = Calendar.current
        let start = generatedAt.startOfWeek()
        let current = date.startOfWeek()
        let weeks = calendar.dateComponents([.weekOfYear], from: start, to: current).weekOfYear ?? 0
        return max(1, weeks + 1)
    }

    func resolvedSports(at date: Date = Date()) -> [FirestoreSportEntry] {
        let weekIndex = programWeekIndex(at: date)
        return sports.map { $0.resolvedForProgramWeek(weekIndex) }
    }
}

struct FirestoreSportPrescription: Codable, Equatable {
    var weeklyTargetCount: Int
    var durationMinutes: Int
}

struct FirestoreSportEntry: Codable, Identifiable {
    var id: String          // matches ActivityType.rawValue
    var displayName: String
    var weeklyTargetCount: Int
    var completedThisWeek: Int
    var durationMinutes: Int
    var weekResetDate: Date  // Monday of the current week
    var hasProgression: Bool
    var initialPrescription: FirestoreSportPrescription?
    var targetPrescription: FirestoreSportPrescription?

    init(
        id: String,
        displayName: String,
        weeklyTargetCount: Int,
        completedThisWeek: Int,
        durationMinutes: Int,
        weekResetDate: Date,
        hasProgression: Bool = false,
        initialPrescription: FirestoreSportPrescription? = nil,
        targetPrescription: FirestoreSportPrescription? = nil
    ) {
        let legacy = FirestoreSportPrescription(
            weeklyTargetCount: max(1, weeklyTargetCount),
            durationMinutes: max(1, durationMinutes)
        )
        let resolvedInitial = initialPrescription ?? legacy
        let resolvedTarget = targetPrescription ?? legacy

        self.id = id
        self.displayName = displayName
        self.weeklyTargetCount = legacy.weeklyTargetCount
        self.completedThisWeek = max(0, completedThisWeek)
        self.durationMinutes = legacy.durationMinutes
        self.weekResetDate = weekResetDate
        self.initialPrescription = resolvedInitial
        self.targetPrescription = resolvedTarget
        self.hasProgression = hasProgression || resolvedInitial != resolvedTarget
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case weeklyTargetCount
        case completedThisWeek
        case durationMinutes
        case weekResetDate
        case hasProgression
        case initialPrescription
        case targetPrescription
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let id = try container.decode(String.self, forKey: .id)
        let displayName = try container.decode(String.self, forKey: .displayName)
        let legacyWeekly = try container.decodeIfPresent(Int.self, forKey: .weeklyTargetCount) ?? 1
        let completed = try container.decodeIfPresent(Int.self, forKey: .completedThisWeek) ?? 0
        let legacyDuration = try container.decodeIfPresent(Int.self, forKey: .durationMinutes) ?? 20
        let weekReset = try container.decodeIfPresent(Date.self, forKey: .weekResetDate) ?? Date().startOfWeek()
        let initial = try container.decodeIfPresent(FirestoreSportPrescription.self, forKey: .initialPrescription)
        let target = try container.decodeIfPresent(FirestoreSportPrescription.self, forKey: .targetPrescription)
        let legacy = FirestoreSportPrescription(
            weeklyTargetCount: max(1, legacyWeekly),
            durationMinutes: max(1, legacyDuration)
        )
        let resolvedInitial = initial ?? legacy
        let resolvedTarget = target ?? legacy
        let progression = (try container.decodeIfPresent(Bool.self, forKey: .hasProgression))
            ?? (resolvedInitial != resolvedTarget)

        self.init(
            id: id,
            displayName: displayName,
            weeklyTargetCount: legacy.weeklyTargetCount,
            completedThisWeek: completed,
            durationMinutes: legacy.durationMinutes,
            weekResetDate: weekReset,
            hasProgression: progression,
            initialPrescription: resolvedInitial,
            targetPrescription: resolvedTarget
        )
    }

    var resolvedInitialPrescription: FirestoreSportPrescription {
        initialPrescription ?? FirestoreSportPrescription(
            weeklyTargetCount: max(1, weeklyTargetCount),
            durationMinutes: max(1, durationMinutes)
        )
    }

    var resolvedTargetPrescription: FirestoreSportPrescription {
        targetPrescription ?? FirestoreSportPrescription(
            weeklyTargetCount: max(1, weeklyTargetCount),
            durationMinutes: max(1, durationMinutes)
        )
    }

    func resolvedForProgramWeek(_ weekIndex: Int) -> FirestoreSportEntry {
        let phase = weekIndex <= 1 ? resolvedInitialPrescription : resolvedTargetPrescription
        var copy = self
        copy.weeklyTargetCount = phase.weeklyTargetCount
        copy.durationMinutes = phase.durationMinutes
        return copy
    }
}

// Maps to the 'titles' Firestore collection
struct FirestoreTitle: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var minTotalActionsRequired: Int
    var displayOrder: Int
}
