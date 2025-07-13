import SwiftUI
import Foundation
import Combine
import CoreLocation

// MARK: - Simplified Auth Manager (Compatible with Firebase when ready)
class FirebaseAuthManager: ObservableObject {
    @Published var user: IcebreakerUser?
    @Published var userProfile: IcebreakerUserProfile?
    @Published var isSignedIn = false
    @Published var hasCompletedOnboarding = false
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadSavedUser()
    }
    
    // MARK: - Authentication Methods
    
    func signUp(email: String, password: String, firstName: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = ""
        
        // Simulate Firebase API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { 
                DispatchQueue.main.async {
                    completion(false)
                }
                return 
            }
            
            // Ensure all UI updates happen on main thread
            DispatchQueue.main.async {
                // Basic validation
                guard !email.isEmpty, !password.isEmpty, !firstName.isEmpty else {
                    self.errorMessage = "Please fill in all fields"
                    self.isLoading = false
                    completion(false)
                    return
                }
                
                guard email.contains("@") else {
                    self.errorMessage = "Please enter a valid email"
                    self.isLoading = false
                    completion(false)
                    return
                }
                
                guard password.count >= 6 else {
                    self.errorMessage = "Password must be at least 6 characters"
                    self.isLoading = false
                    completion(false)
                    return
                }
                
                // Create user and profile
                let user = IcebreakerUser(
                    id: UUID().uuidString,
                    firstName: firstName,
                    email: email
                )
                
                let profile = IcebreakerUserProfile(
                    id: user.id,
                    uid: user.id,
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
                    interests: []
                )
                
                self.user = user
                self.userProfile = profile
                self.isSignedIn = true
                // Don't mark onboarding as complete yet - let the onboarding flow handle this
                self.hasCompletedOnboarding = false
                self.isLoading = false
                self.saveUser(user)
                self.saveProfile(profile)
                completion(true)
            }
        }
    }
    
    func signIn(email: String, password: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = ""
        
        // Simulate Firebase API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { 
                DispatchQueue.main.async {
                    completion(false)
                }
                return 
            }
            
            // Ensure all UI updates happen on main thread
            DispatchQueue.main.async {
                guard !email.isEmpty, !password.isEmpty else {
                    self.errorMessage = "Please fill in all fields"
                    self.isLoading = false
                    completion(false)
                    return
                }
                
                guard email.contains("@") else {
                    self.errorMessage = "Please enter a valid email"
                    self.isLoading = false
                    completion(false)
                    return
                }
                
                // Create or load user
                let userFirstName = email.components(separatedBy: "@").first?.capitalized ?? "User"
                let user = IcebreakerUser(
                    id: UUID().uuidString,
                    firstName: userFirstName,
                    email: email
                )
                
                let profile = IcebreakerUserProfile(
                    id: user.id,
                    uid: user.id,
                    email: email,
                    firstName: user.firstName,
                    createdAt: Date(),
                    isVisible: true,
                    visibilityRange: 25.0,
                    answers: [],
                    lastActive: Date(),
                    location: nil,
                    profileImageURL: "",
                    bio: "",
                    interests: []
                )
                
                self.user = user
                self.userProfile = profile
                self.isSignedIn = true
                // Existing users have completed onboarding
                self.hasCompletedOnboarding = true
                self.isLoading = false
                self.saveUser(user)
                self.saveProfile(profile)
                completion(true)
            }
        }
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "has_completed_onboarding")
        
        // Also save the current user and profile to ensure persistence
        if let user = user {
            saveUser(user)
        }
        if let profile = userProfile {
            saveProfile(profile)
        }
        
        print("✅ Onboarding completed and saved")
    }
    
    func signOut() {
        user = nil
        userProfile = nil
        isSignedIn = false
        hasCompletedOnboarding = false
        UserDefaults.standard.removeObject(forKey: "saved_user")
        UserDefaults.standard.removeObject(forKey: "saved_profile")
        UserDefaults.standard.removeObject(forKey: "has_completed_onboarding")
    }
    
    // MARK: - Profile Management
    
    func updateProfile(firstName: String? = nil, bio: String? = nil, interests: [String]? = nil) {
        guard var profile = userProfile else { return }
        
        if let firstName = firstName { 
            profile.firstName = firstName
            user?.firstName = firstName
        }
        if let bio = bio { profile.bio = bio }
        if let interests = interests { profile.interests = interests }
        
        userProfile = profile
        if let user = user {
            saveUser(user)
        }
        saveProfile(profile)
    }
    
    func updateVisibility(isVisible: Bool) {
        guard var profile = userProfile else { return }
        profile.isVisible = isVisible
        profile.lastActive = Date()
        userProfile = profile
        saveProfile(profile)
    }
    
    func updateVisibilityRange(_ range: Double) {
        guard var profile = userProfile else { return }
        profile.visibilityRange = range
        userProfile = profile
        saveProfile(profile)
    }
    
    // MARK: - Local Storage (Replace with Firebase when ready)
    
    private func loadSavedUser() {
        // Load saved user
        if let userData = UserDefaults.standard.data(forKey: "saved_user"),
           let user = try? JSONDecoder().decode(IcebreakerUser.self, from: userData) {
            self.user = user
            self.isSignedIn = true
        }
        
        // Load saved profile
        if let profileData = UserDefaults.standard.data(forKey: "saved_profile"),
           let profile = try? JSONDecoder().decode(IcebreakerUserProfile.self, from: profileData) {
            self.userProfile = profile
        }
        
        // Load onboarding completion status
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "has_completed_onboarding")
        
        // If user exists but hasn't completed onboarding, ensure they're still signed in
        if user != nil && !hasCompletedOnboarding {
            isSignedIn = true
        }
        
        // Debug logging
        print("🔄 Auth State Loaded:")
        print("   - User exists: \(user != nil)")
        print("   - Is signed in: \(isSignedIn)")
        print("   - Onboarding complete: \(hasCompletedOnboarding)")
    }
    
    private func saveUser(_ user: IcebreakerUser) {
        if let userData = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(userData, forKey: "saved_user")
        }
    }
    
    private func saveProfile(_ profile: IcebreakerUserProfile) {
        if let profileData = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(profileData, forKey: "saved_profile")
        }
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
    
    var isActiveNow: Bool {
        Date().timeIntervalSince(lastActive) < 300 // 5 minutes
    }
}