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
}

struct FirestoreSportEntry: Codable, Identifiable {
    var id: String          // matches ActivityType.rawValue
    var displayName: String
    var weeklyTargetCount: Int
    var completedThisWeek: Int
    var durationMinutes: Int
    var weekResetDate: Date  // Monday of the current week
}

// Maps to the 'titles' Firestore collection
struct FirestoreTitle: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var minTotalActionsRequired: Int
    var displayOrder: Int
}
