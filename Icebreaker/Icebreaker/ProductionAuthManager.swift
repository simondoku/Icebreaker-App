import Foundation
import CoreLocation

// MARK: - Production-Ready Auth Manager (without Firebase for now)
class ProductionAuthManager: ObservableObject {
    @Published var isSignedIn = false
    @Published var currentUser: AppUser?
    @Published var isLoading = false
    @Published var errorMessage = ""
    
    // Temporary storage - in production this would be Firebase
    private let userDefaults = UserDefaults.standard
    
    init() {
        loadSavedUser()
    }
    
    func signUp(email: String, password: String, firstName: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = ""
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
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
            
            // Create user
            let user = AppUser(
                id: UUID().uuidString,
                email: email,
                firstName: firstName,
                createdAt: Date(),
                isVisible: true,
                visibilityRange: 25.0
            )
            
            self.currentUser = user
            self.isSignedIn = true
            self.isLoading = false
            self.saveUser(user)
            completion(true)
        }
    }
    
    func signIn(email: String, password: String, completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = ""
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            // For demo purposes, any valid email/password works
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
            let user = AppUser(
                id: UUID().uuidString,
                email: email,
                firstName: email.components(separatedBy: "@").first?.capitalized ?? "User",
                createdAt: Date(),
                isVisible: true,
                visibilityRange: 25.0
            )
            
            self.currentUser = user
            self.isSignedIn = true
            self.isLoading = false
            self.saveUser(user)
            completion(true)
        }
    }
    
    func signOut() {
        currentUser = nil
        isSignedIn = false
        userDefaults.removeObject(forKey: "saved_user")
    }
    
    func loadSavedUser() {
        if let userData = userDefaults.data(forKey: "saved_user"),
           let user = try? JSONDecoder().decode(AppUser.self, from: userData) {
            currentUser = user
            isSignedIn = true
        }
    }
    
    private func saveUser(_ user: AppUser) {
        if let userData = try? JSONEncoder().encode(user) {
            userDefaults.set(userData, forKey: "saved_user")
        }
    }
    
    func updateProfile(firstName: String? = nil, visibilityRange: Double? = nil, isVisible: Bool? = nil) {
        guard var user = currentUser else { return }
        
        if let firstName = firstName { user.firstName = firstName }
        if let range = visibilityRange { user.visibilityRange = range }
        if let visible = isVisible { user.isVisible = visible }
        
        currentUser = user
        saveUser(user)
    }
}

// MARK: - App User Model
struct AppUser: Codable, Identifiable {
    let id: String
    let email: String
    var firstName: String
    let createdAt: Date
    var isVisible: Bool
    var visibilityRange: Double
    var location: LocationPoint?
    var answers: [String] = []
    var lastActive: Date = Date()
    
    struct LocationPoint: Codable {
        let latitude: Double
        let longitude: Double
        
        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }
    }
    
    var isActiveNow: Bool {
        Date().timeIntervalSince(lastActive) < 300 // 5 minutes
    }
}