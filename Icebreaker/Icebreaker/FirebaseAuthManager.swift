import SwiftUI
import Foundation
import Combine
import CoreLocation
import Firebase
import FirebaseAuth
import FirebaseFirestore

// MARK: - Real Firebase Auth Manager
class FirebaseAuthManager: ObservableObject {
    @Published var user: IcebreakerUser?
    @Published var userProfile: IcebreakerUserProfile?
    @Published var isSignedIn = false
    @Published var hasCompletedOnboarding = false
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private var cancellables = Set<AnyCancellable>()
    private let db = Firestore.firestore()
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    init() {
        setupAuthStateListener()
    }
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    // MARK: - Auth State Management
    
    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] auth, firebaseUser in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let firebaseUser = firebaseUser {
                    // User is signed in
                    self.isSignedIn = true
                    await self.loadUserProfile(uid: firebaseUser.uid)
                } else {
                    // User is signed out
                    self.user = nil
                    self.userProfile = nil
                    self.isSignedIn = false
                    self.hasCompletedOnboarding = false
                }
            }
        }
    }
    
    // MARK: - Authentication Methods
    
    func signUp(email: String, password: String, firstName: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = ""
        
        // Validate input
        guard !email.isEmpty, !password.isEmpty, !firstName.isEmpty else {
            errorMessage = "Please fill in all fields"
            isLoading = false
            completion(false)
            return
        }
        
        guard email.contains("@") else {
            errorMessage = "Please enter a valid email"
            isLoading = false
            completion(false)
            return
        }
        
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters"
            isLoading = false
            completion(false)
            return
        }
        
        // Create Firebase user
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] authResult, error in
            Task { @MainActor in
                guard let self = self else { 
                    completion(false)
                    return 
                }
                
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    completion(false)
                    return
                }
                
                guard let firebaseUser = authResult?.user else {
                    self.errorMessage = "Failed to create user account"
                    completion(false)
                    return
                }
                
                // Create user profile in Firestore
                await self.createUserProfile(
                    uid: firebaseUser.uid,
                    email: email,
                    firstName: firstName
                )
                
                completion(true)
            }
        }
    }
    
    func signIn(email: String, password: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = ""
        
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please fill in all fields"
            isLoading = false
            completion(false)
            return
        }
        
        guard email.contains("@") else {
            errorMessage = "Please enter a valid email"
            isLoading = false
            completion(false)
            return
        }
        
        // Sign in with Firebase
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] authResult, error in
            Task { @MainActor in
                guard let self = self else { 
                    completion(false)
                    return 
                }
                
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    completion(false)
                    return
                }
                
                guard let firebaseUser = authResult?.user else {
                    self.errorMessage = "Failed to sign in"
                    completion(false)
                    return
                }
                
                // Load user profile
                await self.loadUserProfile(uid: firebaseUser.uid)
                completion(true)
            }
        }
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
        
        // Update onboarding status in Firestore
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        Task {
            do {
                try await db.collection("users").document(uid).updateData([
                    "hasCompletedOnboarding": true,
                    "lastActive": Timestamp()
                ])
                print("✅ Onboarding completed and saved to Firestore")
            } catch {
                print("❌ Error updating onboarding status: \(error)")
            }
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            // Auth state listener will handle clearing local state
        } catch {
            errorMessage = "Failed to sign out: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Profile Management
    
    func updateProfile(firstName: String? = nil, bio: String? = nil, interests: [String]? = nil) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard var profile = userProfile else { return }
        
        var updates: [String: Any] = [:]
        
        if let firstName = firstName { 
            profile.firstName = firstName
            user?.firstName = firstName
            updates["firstName"] = firstName
        }
        if let bio = bio { 
            profile.bio = bio
            updates["bio"] = bio
        }
        if let interests = interests { 
            profile.interests = interests
            updates["interests"] = interests
        }
        
        updates["lastActive"] = Timestamp()
        
        userProfile = profile
        
        // Update in Firestore
        Task {
            do {
                try await db.collection("users").document(uid).updateData(updates)
            } catch {
                print("❌ Error updating profile: \(error)")
            }
        }
    }
    
    func updateVisibility(isVisible: Bool) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard var profile = userProfile else { return }
        
        profile.isVisible = isVisible
        profile.lastActive = Date()
        userProfile = profile
        
        // Update in Firestore
        Task {
            do {
                try await db.collection("users").document(uid).updateData([
                    "isVisible": isVisible,
                    "lastActive": Timestamp()
                ])
            } catch {
                print("❌ Error updating visibility: \(error)")
            }
        }
    }
    
    func updateVisibilityRange(_ range: Double) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard var profile = userProfile else { return }
        
        profile.visibilityRange = range
        userProfile = profile
        
        // Update in Firestore
        Task {
            do {
                try await db.collection("users").document(uid).updateData([
                    "visibilityRange": range,
                    "lastActive": Timestamp()
                ])
            } catch {
                print("❌ Error updating visibility range: \(error)")
            }
        }
    }
    
    func updateLocation(_ location: CLLocation) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard var profile = userProfile else { return }
        
        let geoPoint = IcebreakerGeoPoint(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        
        profile.location = geoPoint
        profile.lastActive = Date()
        userProfile = profile
        
        // Update in Firestore with BOTH formats for compatibility
        Task {
            do {
                try await db.collection("users").document(uid).updateData([
                    // New nested format (for MatchEngine)
                    "location": [
                        "latitude": location.coordinate.latitude,
                        "longitude": location.coordinate.longitude
                    ],
                    // Legacy direct format (for compatibility)
                    "latitude": location.coordinate.latitude,
                    "longitude": location.coordinate.longitude,
                    "isVisible": true,
                    "lastActive": Timestamp(),
                    "lastLocationUpdate": Timestamp()
                ])
                print("✅ Location updated in Firebase: \(location.coordinate.latitude), \(location.coordinate.longitude)")
            } catch {
                print("❌ Error updating location: \(error)")
            }
        }
    }
    
    // MARK: - Firestore Operations
    
    @MainActor
    private func createUserProfile(uid: String, email: String, firstName: String) async {
        let profile = IcebreakerUserProfile(
            id: uid,
            uid: uid,
            email: email,
            firstName: firstName,
            createdAt: Date(),
            isVisible: true,
            visibilityRange: 25.0,
            answers: [],
            lastActive: Date(),
            location: nil,
            profileImageURL: "",
            bio: "",
            interests: [],
            hasCompletedOnboarding: false
        )
        
        let user = IcebreakerUser(
            id: uid,
            firstName: firstName,
            email: email
        )
        
        do {
            // Save to Firestore
            let profileData: [String: Any] = [
                "uid": uid,
                "email": email,
                "firstName": firstName,
                "createdAt": Timestamp(),
                "isVisible": true,
                "visibilityRange": 25.0,
                "answers": [],
                "lastActive": Timestamp(),
                "profileImageURL": "",
                "bio": "",
                "interests": [],
                "hasCompletedOnboarding": false
            ]
            
            try await db.collection("users").document(uid).setData(profileData)
            
            // Update local state
            self.user = user
            self.userProfile = profile
            self.hasCompletedOnboarding = false
            
            print("✅ User profile created in Firestore")
        } catch {
            self.errorMessage = "Failed to create user profile: \(error.localizedDescription)"
            print("❌ Error creating user profile: \(error)")
        }
    }
    
    @MainActor
    private func loadUserProfile(uid: String) async {
        do {
            let document = try await db.collection("users").document(uid).getDocument()
            
            guard let data = document.data() else {
                print("❌ No user profile found for uid: \(uid)")
                return
            }
            
            // Parse Firestore data
            let profile = IcebreakerUserProfile(
                id: uid,
                uid: uid,
                email: data["email"] as? String ?? "",
                firstName: data["firstName"] as? String ?? "",
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
                isVisible: data["isVisible"] as? Bool ?? true,
                visibilityRange: data["visibilityRange"] as? Double ?? 25.0,
                answers: data["answers"] as? [String] ?? [],
                lastActive: (data["lastActive"] as? Timestamp)?.dateValue() ?? Date(),
                location: parseLocation(from: data["location"]),
                profileImageURL: data["profileImageURL"] as? String ?? "",
                bio: data["bio"] as? String ?? "",
                interests: data["interests"] as? [String] ?? [],
                hasCompletedOnboarding: data["hasCompletedOnboarding"] as? Bool ?? false
            )
            
            let user = IcebreakerUser(
                id: uid,
                firstName: profile.firstName,
                email: profile.email
            )
            
            self.user = user
            self.userProfile = profile
            self.hasCompletedOnboarding = profile.hasCompletedOnboarding
            
            print("✅ User profile loaded from Firestore")
        } catch {
            self.errorMessage = "Failed to load user profile: \(error.localizedDescription)"
            print("❌ Error loading user profile: \(error)")
        }
    }
    
    private func parseLocation(from data: Any?) -> IcebreakerGeoPoint? {
        guard let locationData = data as? [String: Any],
              let latitude = locationData["latitude"] as? Double,
              let longitude = locationData["longitude"] as? Double else {
            return nil
        }
        
        return IcebreakerGeoPoint(latitude: latitude, longitude: longitude)
    }
}

// MARK: - Location Point for IcebreakerUser
struct IcebreakerGeoPoint: Codable {
    let latitude: Double
    let longitude: Double
}

// Additional profile model that extends the base IcebreakerUser
struct IcebreakerUserProfile: Codable, Identifiable {
    var id: String?
    let uid: String
    let email: String
    var firstName: String
    let createdAt: Date
    var isVisible: Bool
    var visibilityRange: Double
    var answers: [String]
    var lastActive: Date
    var location: IcebreakerGeoPoint?
    var profileImageURL: String
    var bio: String
    var interests: [String]
    var hasCompletedOnboarding: Bool
    
    var isActiveNow: Bool {
        Date().timeIntervalSince(lastActive) < 300 // 5 minutes
    }
}