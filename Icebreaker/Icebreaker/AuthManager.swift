import SwiftUI
import Foundation

class AuthManager: ObservableObject {
    @Published var isSignedIn = false
    @Published var currentUser: User?
    
    private let userDefaultsKey = "current_user"
    
    func signUp(firstName: String, age: Int, bio: String) {
        let newUser = User(
            id: UUID().uuidString,
            firstName: firstName,
            age: age,
            bio: bio,
            location: nil,
            profileImageURL: nil,
            interests: [],
            createdAt: Date()
        )
        
        currentUser = newUser
        isSignedIn = true
        saveUser()
    }
    
    func signOut() {
        currentUser = nil
        isSignedIn = false
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
    }
    
    func loadSavedUser() {
        if let userData = UserDefaults.standard.data(forKey: userDefaultsKey),
           let user = try? JSONDecoder().decode(User.self, from: userData) {
            currentUser = user
            isSignedIn = true
        }
    }
    
    private func saveUser() {
        guard let user = currentUser,
              let userData = try? JSONEncoder().encode(user) else { return }
        UserDefaults.standard.set(userData, forKey: userDefaultsKey)
    }
}