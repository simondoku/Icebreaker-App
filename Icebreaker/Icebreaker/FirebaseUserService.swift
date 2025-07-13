import Foundation
import Firebase
import FirebaseFirestore
import FirebaseAuth
import CoreLocation
import Combine

// MARK: - Firebase User Service
class FirebaseUserService: ObservableObject {
    static let shared = FirebaseUserService()
    
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    
    @Published var currentUser: User?
    @Published var nearbyUsers: [User] = []
    @Published var isLoading = false
    @Published var error: FirebaseServiceError?
    
    private var nearbyUsersListener: ListenerRegistration?
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    init() {
        // Listen for auth state changes
        authStateListener = auth.addStateDidChangeListener { [weak self] _, user in
            if let user = user {
                Task {
                    await self?.loadCurrentUser(userId: user.uid)
                }
            } else {
                self?.currentUser = nil
                self?.nearbyUsers = []
                self?.stopListeningForNearbyUsers()
            }
        }
    }
    
    // MARK: - User Management
    
    func createUser(_ user: User) async throws {
        guard let currentUser = auth.currentUser else {
            throw FirebaseServiceError.notAuthenticated
        }
        
        // Create a new User instance with the Firebase UID using the correct initializer
        let userData = User(
            id: currentUser.uid,
            firstName: user.firstName,
            age: user.age,
            bio: user.bio,
            location: user.location,
            interests: user.interests
        )
        
        // Set additional properties after initialization
        var finalUserData = userData
        finalUserData.lastSeen = Date()
        finalUserData.isOnline = true
        finalUserData.profileImageURL = user.profileImageURL
        finalUserData.createdAt = user.createdAt
        
        do {
            try db.collection("users").document(currentUser.uid).setData(from: finalUserData)
            await MainActor.run {
                self.currentUser = finalUserData
            }
        } catch {
            throw FirebaseServiceError.firebaseError(error)
        }
    }
    
    func loadCurrentUser(userId: String) async {
        await MainActor.run {
            self.isLoading = true
        }
        
        do {
            let document = try await db.collection("users").document(userId).getDocument()
            
            if let user = try? document.data(as: User.self) {
                await MainActor.run {
                    self.currentUser = user
                    self.isLoading = false
                    self.error = nil
                }
            } else {
                await MainActor.run {
                    self.error = .userNotFound
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.error = .firebaseError(error)
                self.isLoading = false
            }
        }
    }
    
    func updateUser(_ user: User) async throws {
        guard let userId = auth.currentUser?.uid else {
            throw FirebaseServiceError.notAuthenticated
        }
        
        var updatedUser = user
        updatedUser.lastSeen = Date()
        
        do {
            try db.collection("users").document(userId).setData(from: updatedUser, merge: true)
            await MainActor.run {
                self.currentUser = updatedUser
            }
        } catch {
            throw FirebaseServiceError.firebaseError(error)
        }
    }
    
    func updateUserLocation(_ location: CLLocation, userId: String) async throws {
        let locationData: [String: Any] = [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "lastLocationUpdate": Timestamp(),
            "isLocationVisible": true
        ]
        
        do {
            try await db.collection("users").document(userId).updateData(locationData)
        } catch {
            throw FirebaseServiceError.firebaseError(error)
        }
    }
    
    func setUserVisibility(_ isVisible: Bool, userId: String) async throws {
        let visibilityData: [String: Any] = [
            "isLocationVisible": isVisible,
            "lastSeen": Timestamp()
        ]
        
        do {
            try await db.collection("users").document(userId).updateData(visibilityData)
        } catch {
            throw FirebaseServiceError.firebaseError(error)
        }
    }
    
    // MARK: - Nearby Users
    
    func startListeningForNearbyUsers(userLocation: CLLocation, radiusKm: Double = 20.0) {
        guard let currentUserId = auth.currentUser?.uid else {
            error = .notAuthenticated
            return
        }
        
        stopListeningForNearbyUsers()
        
        // Calculate approximate coordinate bounds for the radius
        let latitudeDelta = radiusKm / 111.0 // Rough km per degree latitude
        let longitudeDelta = radiusKm / (111.0 * cos(userLocation.coordinate.latitude * .pi / 180))
        
        let minLat = userLocation.coordinate.latitude - latitudeDelta
        let maxLat = userLocation.coordinate.latitude + latitudeDelta
        let minLng = userLocation.coordinate.longitude - longitudeDelta
        let maxLng = userLocation.coordinate.longitude + longitudeDelta
        
        nearbyUsersListener = db.collection("users")
            .whereField("isLocationVisible", isEqualTo: true)
            .whereField("latitude", isGreaterThan: minLat)
            .whereField("latitude", isLessThan: maxLat)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    self?.error = .firebaseError(error)
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                let users = documents.compactMap { document -> User? in
                    do {
                        var user = try document.data(as: User.self)
                        
                        // Filter by longitude and exclude current user
                        if user.id == currentUserId { return nil }
                        
                        guard let userLng = user.longitude,
                              userLng >= minLng && userLng <= maxLng else { return nil }
                        
                        // Calculate actual distance
                        if let userLat = user.latitude, let userLng = user.longitude {
                            let otherUserLocation = CLLocation(latitude: userLat, longitude: userLng)
                            let distance = userLocation.distance(from: otherUserLocation)
                            
                            if distance <= radiusKm * 1000 { // Convert km to meters
                                user.distanceFromUser = distance
                                return user
                            }
                        }
                        
                        return nil
                    } catch {
                        print("Error decoding user: \(error)")
                        return nil
                    }
                }
                
                DispatchQueue.main.async {
                    self?.nearbyUsers = users.sorted { ($0.distanceFromUser ?? 0) < ($1.distanceFromUser ?? 0) }
                }
            }
    }
    
    func stopListeningForNearbyUsers() {
        nearbyUsersListener?.remove()
        nearbyUsersListener = nil
    }
    
    func refreshNearbyUsers(userLocation: CLLocation, radiusKm: Double = 20.0) {
        startListeningForNearbyUsers(userLocation: userLocation, radiusKm: radiusKm)
    }
    
    // MARK: - User Status
    
    func setUserOnlineStatus(_ isOnline: Bool) async {
        guard let userId = auth.currentUser?.uid else { return }
        
        let statusData: [String: Any] = [
            "isOnline": isOnline,
            "lastSeen": Timestamp()
        ]
        
        do {
            try await db.collection("users").document(userId).updateData(statusData)
        } catch {
            print("Failed to update online status: \(error)")
        }
    }
    
    // MARK: - Matches and Connections
    
    func sendConnectionRequest(to userId: String) async throws {
        guard let currentUserId = auth.currentUser?.uid else {
            throw FirebaseServiceError.notAuthenticated
        }
        
        let connectionData: [String: Any] = [
            "fromUserId": currentUserId,
            "toUserId": userId,
            "status": "pending",
            "createdAt": Timestamp(),
            "type": "connection_request"
        ]
        
        do {
            try await db.collection("connections").addDocument(data: connectionData)
        } catch {
            throw FirebaseServiceError.firebaseError(error)
        }
    }
    
    func getConnectionStatus(with userId: String) async throws -> FirebaseConnectionStatus {
        guard let currentUserId = auth.currentUser?.uid else {
            throw FirebaseServiceError.notAuthenticated
        }
        
        // Check for existing connection
        let query = db.collection("connections")
            .whereFilter(Filter.orFilter([
                Filter.andFilter([
                    Filter.whereField("fromUserId", isEqualTo: currentUserId),
                    Filter.whereField("toUserId", isEqualTo: userId)
                ]),
                Filter.andFilter([
                    Filter.whereField("fromUserId", isEqualTo: userId),
                    Filter.whereField("toUserId", isEqualTo: currentUserId)
                ])
            ]))
        
        do {
            let snapshot = try await query.getDocuments()
            
            if let document = snapshot.documents.first {
                let data = document.data()
                let status = data["status"] as? String ?? "unknown"
                let fromUserId = data["fromUserId"] as? String ?? ""
                
                switch status {
                case "pending":
                    return fromUserId == currentUserId ? .requestSent : .requestReceived
                case "accepted":
                    return .connected
                case "declined":
                    return .declined
                default:
                    return .none
                }
            }
            
            return .none
        } catch {
            throw FirebaseServiceError.firebaseError(error)
        }
    }
    
    // MARK: - Cleanup
    
    deinit {
        stopListeningForNearbyUsers()
        if let authStateListener = authStateListener {
            Auth.auth().removeStateDidChangeListener(authStateListener)
        }
    }
}

// MARK: - Firebase Service Errors

enum FirebaseServiceError: Error, LocalizedError {
    case notAuthenticated
    case userNotFound
    case firebaseError(Error)
    case invalidData
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .userNotFound:
            return "User not found"
        case .firebaseError(let error):
            return "Firebase error: \(error.localizedDescription)"
        case .invalidData:
            return "Invalid data format"
        case .networkError:
            return "Network connection error"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to continue"
        case .userNotFound:
            return "Please complete your profile setup"
        case .firebaseError, .networkError:
            return "Check your internet connection and try again"
        case .invalidData:
            return "Please refresh and try again"
        }
    }
}

// MARK: - Connection Status for Firebase (different from RealTime chat status)

enum FirebaseConnectionStatus {
    case none
    case requestSent
    case requestReceived
    case connected
    case declined
    
    var displayText: String {
        switch self {
        case .none:
            return "Connect"
        case .requestSent:
            return "Request Sent"
        case .requestReceived:
            return "Accept Request"
        case .connected:
            return "Connected"
        case .declined:
            return "Declined"
        }
    }
}