import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Updates private data and its allowlisted discovery projection atomically.
/// Transactions retry against current data so a location update cannot undo a visibility change.
enum PrivateProfileStore {
    static func save(uid: String, updates: [String: Any] = [:]) async throws {
        guard Auth.auth().currentUser?.uid == uid else {
            throw NSError(domain: "PrivateProfileStore", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Please sign in to update your profile."])
        }
        let db = Firestore.firestore()
        let privateRef = db.collection("users").document(uid)
        let discoveryRef = db.collection("discoveryProfiles").document(uid)
        _ = try await db.runTransaction { transaction, errorPointer in
            do {
                let snapshot = try transaction.getDocument(privateRef)
                // Sign-in may finish before account creation writes the initial profile.
                guard snapshot.exists || !updates.isEmpty else { return nil }
                var data = snapshot.data() ?? [:]
                data.merge(updates) { _, new in new }
                transaction.setData(data, forDocument: privateRef)
                // Replace, never merge: hiding removes every previously shared field.
                transaction.setData(DiscoveryProfile.project(data), forDocument: discoveryRef)
                return nil
            } catch let error as NSError {
                errorPointer?.pointee = error
                return nil
            }
        }
    }
}
