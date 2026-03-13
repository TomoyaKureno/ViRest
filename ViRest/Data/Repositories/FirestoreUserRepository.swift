//
//  FirestoreUserRepository.swift
//  ViRest
//
//  Created by Joshua Valentine Manik on 13/03/26.
//

import Foundation
import FirebaseFirestore

@MainActor
final class FirestoreUserRepository {
    private let db = Firestore.firestore()
    private var cachedUser: FirestoreUser?

    // Create or update user document on sign-in
    func ensureUserExists(authUser: AuthUser) async throws {
        let ref = db.collection("users").document(authUser.id)
        let snapshot = try await ref.getDocument()

        if !snapshot.exists {
            // First sign-in: create document
            var newUser = FirestoreUser(from: authUser)
            // Assign default title (lowest displayOrder)
            let defaultTitle = try await fetchLowestTitle()
            newUser.currentTitleId = defaultTitle?.id ?? ""
            try ref.setData(from: newUser)
        } else {
            // Returning user: update lastActiveAt
            try await ref.updateData(["lastActiveAt": FieldValue.serverTimestamp()])
        }
    }

    func loadUser(userId: String) async throws -> FirestoreUser? {
        let snapshot = try await db.collection("users").document(userId).getDocument()
        let user = try snapshot.data(as: FirestoreUser.self)
        self.cachedUser = user
        return user
    }

    func saveProfile(userId: String, profile: UserProfileInput) async throws {
        let ref = db.collection("users").document(userId)
        let data: [String: Any] = [
            "age": profile.age as Any,
            "restingHeartRate": profile.restingHeartRateRange.midpoint as Any,
            "targetRestingHeartRate": profile.targetRestingHeartRateRange.midpoint as Any,
            "displayName": profile.fullName,
            "lastActiveAt": FieldValue.serverTimestamp()
        ]
        try await ref.updateData(data)
    }

    func saveSportPlan(userId: String, plan: FirestoreSportPlan) async throws {
        let ref = db.collection("users").document(userId)
        let encoded = try Firestore.Encoder().encode(plan)
        try await ref.updateData(["sportPlan": encoded])
    }

    // Called every time user taps '+' on a sport
    func recordCheckIn(userId: String, sportId: String) async throws {
        let ref = db.collection("users").document(userId)
        try await ref.updateData([
            "totalActionsCompleted": FieldValue.increment(Int64(1)),
            "lastActiveAt": FieldValue.serverTimestamp(),
            // Update the specific sport's completedThisWeek counter
            // Uses dot notation to update nested array item
            // Note: with array of structs you'll need a Cloud Function or
            // re-read + write approach (see Phase 4 for the full pattern)
        ])
        // Re-read and update the sport plan's completedThisWeek
        // (Firestore cannot atomically update inside arrays without transactions)
        try await incrementSportCount(userId: userId, sportId: sportId)
    }

    private func incrementSportCount(userId: String, sportId: String) async throws {
        let ref = db.collection("users").document(userId)
        _ = try await db.runTransaction { transaction, errorPointer in
            let snapshot: DocumentSnapshot
            do { snapshot = try transaction.getDocument(ref) }
            catch { errorPointer?.pointee = error as NSError; return nil }

            guard var user = try? snapshot.data(as: FirestoreUser.self),
                  var plan = user.sportPlan else { return nil }

            for i in plan.sports.indices where plan.sports[i].id == sportId {
                plan.sports[i].completedThisWeek += 1
            }
            user.sportPlan = plan
            if let encoded = try? Firestore.Encoder().encode(plan) {
                transaction.updateData(["sportPlan": encoded], forDocument: ref)
            }
            return nil
        }
    }

    // Fetch all titles, return the one with lowest minTotalActionsRequired
    func fetchLowestTitle() async throws -> FirestoreTitle? {
        let snapshot = try await db.collection("titles")
            .order(by: "displayOrder", descending: false)
            .limit(to: 1)
            .getDocuments()
        return try snapshot.documents.first.map { try $0.data(as: FirestoreTitle.self) }
    }

    // Evaluate and update title based on totalActionsCompleted
    func updateTitleIfNeeded(userId: String, totalActions: Int) async throws {
        let snapshot = try await db.collection("titles")
            .order(by: "minTotalActionsRequired", descending: false)
            .getDocuments()
        let titles = try snapshot.documents.map { try $0.data(as: FirestoreTitle.self) }

        // Find the highest title the user qualifies for
        let earned = titles.filter { $0.minTotalActionsRequired <= totalActions }
            .max(by: { $0.minTotalActionsRequired < $1.minTotalActionsRequired })

        if let title = earned, let titleId = title.id {
            try await db.collection("users").document(userId)
                .updateData(["currentTitleId": titleId])
        }
    }

    func saveCheckInHistory(
        userId: String,
        sportId: String,
        sportName: String,
        durationMinutes: Int
    ) async throws {
        let entry = CheckInHistoryEntry(
            sportId: sportId,
            sportName: sportName,
            date: Date(),
            durationMinutes: durationMinutes
        )
        let ref = db.collection("users").document(userId)
            .collection("checkIns").document()
        try ref.setData(from: entry)
    }

    func loadCheckInHistory(userId: String, limit: Int = 30) async throws -> [CheckInHistoryEntry] {
        let snapshot = try await db.collection("users").document(userId)
            .collection("checkIns")
            .order(by: "date", descending: true)
            .limit(to: limit)
            .getDocuments()
        return try snapshot.documents.map { try $0.data(as: CheckInHistoryEntry.self) }
    }

}
