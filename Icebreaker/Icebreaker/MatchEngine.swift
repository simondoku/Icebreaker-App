//
//  MatchEngine.swift
//  Icebreaker
//
//  Created by Simon Doku on 6/23/25.
//

import Foundation
import CoreLocation
import Combine
import Firebase
import FirebaseFirestore
import FirebaseAuth
import SwiftUI

// MARK: - Real User Discovery Match Engine
@MainActor
class MatchEngine: ObservableObject {
    static let shared = MatchEngine()
    
    @Published var currentMatches: [MatchResult] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Compatibility properties
    @Published var matches: [MatchResult] = []
    @Published var nearbyUsers: [User] = []
    @Published var isScanning = false
    
    private let db = Firestore.firestore()
    private let aiService = AIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Real-time listeners
    private var nearbyUsersListener: ListenerRegistration?
    private var currentUserListener: ListenerRegistration?
    
    // Configuration
    private let maxMatchDistance: Double = 50.0 // kilometers
    private let minCompatibilityScore: Double = 0.3 // Lowered from 0.5 to 0.3
    private let maxMatchesPerSearch = 20
    private let refreshInterval: TimeInterval = 30.0 // 30 seconds
    
    init() {
        setupLocationObserver()
    }
    
    deinit {
        nearbyUsersListener?.remove()
        currentUserListener?.remove()
    }
    
    // MARK: - Setup and Configuration
    
    private func setupLocationObserver() {
        // Listen for location updates to refresh matches
        NotificationCenter.default.publisher(for: .userLocationUpdated)
            .debounce(for: .seconds(5), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshMatchesForCurrentUser()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Main Discovery Methods
    
    func findMatches(for currentUser: User) async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        
        do {
            // 1. Get current user's location
            guard let userLocation = getCurrentUserLocation(from: currentUser) else {
                await MainActor.run {
                    self.errorMessage = "Location required for finding matches"
                    self.isLoading = false
                }
                return
            }
            
            // 2. Find nearby users from Firestore
            let nearbyUsers = try await findNearbyUsersInFirestore(
                userLocation: userLocation,
                currentUserId: currentUser.id
            )
            
            await MainActor.run {
                self.nearbyUsers = nearbyUsers
            }
            
            // 3. Calculate compatibility for each nearby user
            let matchResults = await calculateCompatibilityScores(
                currentUser: currentUser,
                potentialMatches: nearbyUsers
            )
            
            // 4. Filter and sort matches
            let filteredMatches = matchResults
                .filter { $0.compatibilityScore >= minCompatibilityScore }
                .sorted { $0.compatibilityScore > $1.compatibilityScore }
                .prefix(maxMatchesPerSearch)
            
            await MainActor.run {
                self.currentMatches = Array(filteredMatches)
                self.matches = Array(filteredMatches)
                self.isLoading = false
                
                print("✅ Found \(filteredMatches.count) compatible matches")
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to find matches: \(error.localizedDescription)"
                self.isLoading = false
                print("❌ Match finding error: \(error)")
            }
        }
    }
    
    func findMatchesForCurrentUser() async {
        // Get current authenticated user
        guard let firebaseUser = Auth.auth().currentUser else {
            await MainActor.run {
                self.errorMessage = "Please sign in to find matches"
            }
            return
        }
        
        do {
            // Get user profile from Firestore
            let userDoc = try await db.collection("users").document(firebaseUser.uid).getDocument()
            
            guard let userData = userDoc.data() else {
                await MainActor.run {
                    self.errorMessage = "User profile not found"
                }
                return
            }
            
            // Convert Firestore data to User model
            let currentUser = try createUserFromFirestoreData(
                id: firebaseUser.uid,
                data: userData
            )
            
            // Find matches for this user
            await findMatches(for: currentUser)
            
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load user profile: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Firestore User Discovery
    
    private func findNearbyUsersInFirestore(
        userLocation: CLLocation,
        currentUserId: String
    ) async throws -> [User] {
        
        // Calculate bounding box for location query
        let boundingBox = calculateBoundingBox(center: userLocation, radiusKm: maxMatchDistance)
        
        // Query Firestore for nearby visible users
        let snapshot = try await db.collection("users")
            .whereField("isVisible", isEqualTo: true)
            .whereField("location.latitude", isGreaterThan: boundingBox.minLat)
            .whereField("location.latitude", isLessThan: boundingBox.maxLat)
            .limit(to: 100)
            .getDocuments()
        
        var nearbyUsers: [User] = []
        
        for document in snapshot.documents {
            // Skip current user
            if document.documentID == currentUserId { continue }
            
            do {
                let userData = document.data()
                let user = try createUserFromFirestoreData(
                    id: document.documentID,
                    data: userData
                )
                
                // Calculate exact distance
                if let userLat = user.latitude, let userLon = user.longitude {
                    let userCLLocation = CLLocation(latitude: userLat, longitude: userLon)
                    let distanceKm = userLocation.distance(from: userCLLocation) / 1000.0
                    
                    // Check if within actual radius (bounding box is approximate)
                    if distanceKm <= maxMatchDistance {
                        var userWithDistance = user
                        userWithDistance.distanceFromUser = distanceKm
                        userWithDistance.isActive = isUserActive(userData)
                        nearbyUsers.append(userWithDistance)
                    }
                }
            } catch {
                print("❌ Error parsing user data: \(error)")
            }
        }
        
        // Sort by distance
        nearbyUsers.sort { 
            ($0.distanceFromUser ?? Double.greatestFiniteMagnitude) < 
            ($1.distanceFromUser ?? Double.greatestFiniteMagnitude) 
        }
        
        print("✅ Found \(nearbyUsers.count) nearby users within \(maxMatchDistance)km")
        return nearbyUsers
    }
    
    private func createUserFromFirestoreData(id: String, data: [String: Any]) throws -> User {
        // Extract location data
        var latitude: Double?
        var longitude: Double?
        
        if let locationData = data["location"] as? [String: Any] {
            latitude = locationData["latitude"] as? Double
            longitude = locationData["longitude"] as? Double
        }
        
        // Extract AI answers
        var aiAnswers: [AIAnswer] = []
        if let answersData = data["answers"] as? [[String: Any]] {
            for answerData in answersData {
                if let questionId = answerData["questionId"] as? String,
                   let questionText = answerData["questionText"] as? String,
                   let answer = answerData["answer"] as? String {
                    
                    aiAnswers.append(AIAnswer(
                        questionId: questionId,
                        questionText: questionText,
                        answer: answer
                    ))
                }
            }
        }
        
        // Create User model
        var user = User(
            id: id,
            firstName: data["firstName"] as? String ?? "Unknown",
            age: data["age"] as? Int ?? 25,
            bio: data["bio"] as? String ?? "",
            location: data["location"] as? String ?? "Unknown",
            interests: data["interests"] as? [String] ?? []
        )
        
        user.latitude = latitude
        user.longitude = longitude
        user.aiAnswers = aiAnswers
        user.isVisible = data["isVisible"] as? Bool ?? false
        user.profileImageURL = data["profileImageURL"] as? String
        user.lastSeen = (data["lastActive"] as? Timestamp)?.dateValue()
        user.createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        
        return user
    }
    
    private func isUserActive(_ userData: [String: Any]) -> Bool {
        guard let lastActive = (userData["lastActive"] as? Timestamp)?.dateValue() else {
            return false
        }
        
        // Consider user active if they were online in the last 5 minutes
        return Date().timeIntervalSince(lastActive) < 300
    }
    
    // MARK: - Compatibility Calculation
    
    private func calculateCompatibilityScores(
        currentUser: User,
        potentialMatches: [User]
    ) async -> [MatchResult] {
        
        var matchResults: [MatchResult] = []
        
        for potentialMatch in potentialMatches {
            if let matchResult = await calculateSingleCompatibility(
                currentUser: currentUser,
                potentialMatch: potentialMatch
            ) {
                matchResults.append(matchResult)
            }
        }
        
        return matchResults
    }
    
    private func calculateSingleCompatibility(
        currentUser: User,
        potentialMatch: User
    ) async -> MatchResult? {
        
        // Find shared interests
        let sharedInterests = Set(currentUser.interests).intersection(Set(potentialMatch.interests))
        let interestCompatibility = Double(sharedInterests.count) / Double(max(currentUser.interests.count, 1))
        
        // Find shared AI answers
        let sharedAnswers = findSharedAnswers(
            user1Answers: currentUser.aiAnswers,
            user2Answers: potentialMatch.aiAnswers
        )
        
        var answerCompatibility = 0.0
        var analyzedAnswers: [MatchResult.SharedAnswer] = []
        
        if !sharedAnswers.isEmpty {
            for sharedAnswer in sharedAnswers {
                let compatibility = calculateAnswerCompatibility(
                    answer1: sharedAnswer.userAnswer.answer,
                    answer2: sharedAnswer.matchAnswer.answer
                )
                
                answerCompatibility += compatibility
                analyzedAnswers.append(MatchResult.SharedAnswer(
                    questionText: sharedAnswer.questionText,
                    userAnswer: sharedAnswer.userAnswer.answer,
                    matchAnswer: sharedAnswer.matchAnswer.answer,
                    compatibility: compatibility
                ))
            }
            answerCompatibility /= Double(sharedAnswers.count)
        }
        
        // Calculate overall compatibility with better handling for users with no data
        var overallCompatibility = 0.4 // Base compatibility for new users
        
        // If both users have some data, calculate weighted compatibility
        if !currentUser.interests.isEmpty || !currentUser.aiAnswers.isEmpty ||
           !potentialMatch.interests.isEmpty || !potentialMatch.aiAnswers.isEmpty {
            
            var weightedScore = 0.0
            var totalWeight = 0.0
            
            // Add interest compatibility if either user has interests
            if !currentUser.interests.isEmpty || !potentialMatch.interests.isEmpty {
                weightedScore += interestCompatibility * 0.3
                totalWeight += 0.3
            }
            
            // Add answer compatibility if both users have answered questions
            if !sharedAnswers.isEmpty {
                weightedScore += answerCompatibility * 0.7
                totalWeight += 0.7
            }
            
            // If we have any weighted data, use it
            if totalWeight > 0 {
                overallCompatibility = weightedScore / totalWeight
            }
            
            // Boost compatibility slightly for having any shared data
            if !sharedInterests.isEmpty || !sharedAnswers.isEmpty {
                overallCompatibility += 0.1
            }
        }
        
        // Ensure minimum compatibility for proximity
        overallCompatibility = max(overallCompatibility, 0.35)
        
        // Debug print compatibility calculation
        print("🧮 Compatibility for \(potentialMatch.firstName):")
        print("   - Shared interests: \(sharedInterests.count) -> \(interestCompatibility)")
        print("   - Shared answers: \(sharedAnswers.count) -> \(answerCompatibility)")
        print("   - Overall: \(overallCompatibility)")
        
        // Generate AI insight
        let insight = generateInsight(
            compatibility: overallCompatibility,
            sharedInterests: Array(sharedInterests),
            sharedAnswers: analyzedAnswers,
            matchName: potentialMatch.firstName
        )
        
        return MatchResult(
            user: potentialMatch,
            compatibilityScore: overallCompatibility,
            sharedAnswers: analyzedAnswers,
            aiInsight: insight,
            aiReasoning: insight, // Add the missing aiReasoning parameter
            distance: potentialMatch.distanceFromUser ?? 0,
            matchedAt: Date()
        )
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentUserLocation(from user: User) -> CLLocation? {
        if let lat = user.latitude, let lon = user.longitude {
            return CLLocation(latitude: lat, longitude: lon)
        }
        
        // Fallback to LocationManager
        return LocationManager.shared.location
    }
    
    private func findSharedAnswers(
        user1Answers: [AIAnswer],
        user2Answers: [AIAnswer]
    ) -> [(questionText: String, userAnswer: AIAnswer, matchAnswer: AIAnswer)] {
        
        var sharedAnswers: [(String, AIAnswer, AIAnswer)] = []
        
        for answer1 in user1Answers {
            for answer2 in user2Answers {
                if answer1.questionId == answer2.questionId {
                    sharedAnswers.append((answer1.questionText, answer1, answer2))
                }
            }
        }
        
        return sharedAnswers
    }
    
    private func calculateAnswerCompatibility(answer1: String, answer2: String) -> Double {
        // Improved text similarity calculation
        let words1 = Set(answer1.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty })
        let words2 = Set(answer2.lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty })
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        guard !union.isEmpty else { return 0.0 }
        
        // Jaccard similarity
        let jaccard = Double(intersection.count) / Double(union.count)
        
        // Boost score for longer shared content
        let lengthBonus = min(Double(intersection.count) / 10.0, 0.2)
        
        return min(jaccard + lengthBonus, 1.0)
    }
    
    private func generateInsight(
        compatibility: Double,
        sharedInterests: [String],
        sharedAnswers: [MatchResult.SharedAnswer],
        matchName: String
    ) -> String {
        
        if !sharedInterests.isEmpty && !sharedAnswers.isEmpty {
            let interest = sharedInterests.first!
            return "🎯 You both love \(interest) and have similar perspectives on life"
        } else if !sharedInterests.isEmpty {
            let interests = sharedInterests.prefix(2).joined(separator: " and ")
            return "🎨 You share a passion for \(interests)"
        } else if !sharedAnswers.isEmpty {
            return "💭 You have similar thoughts and values - great foundation for connection"
        } else {
            switch compatibility {
            case 0.7...:
                return "✨ Strong potential for a meaningful connection"
            case 0.5..<0.7:
                return "🌟 You might have interesting conversations together"
            default:
                return "🤔 Different perspectives could lead to intriguing discussions"
            }
        }
    }
    
    private func calculateBoundingBox(center: CLLocation, radiusKm: Double) -> (minLat: Double, maxLat: Double, minLon: Double, maxLon: Double) {
        let radiusLat = radiusKm / 111.0 // Approximate km per degree latitude
        let radiusLon = radiusKm / (111.0 * cos(center.coordinate.latitude * .pi / 180.0))
        
        return (
            minLat: center.coordinate.latitude - radiusLat,
            maxLat: center.coordinate.latitude + radiusLat,
            minLon: center.coordinate.longitude - radiusLon,
            maxLon: center.coordinate.longitude + radiusLon
        )
    }
    
    // MARK: - Public Interface
    
    func refreshMatchesForCurrentUser() {
        Task {
            await findMatchesForCurrentUser()
        }
    }
    
    func startRealTimeMatching() {
        refreshMatchesForCurrentUser()
        
        // Set up periodic refresh
        Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            self?.refreshMatchesForCurrentUser()
        }
    }
    
    func clearMatches() {
        currentMatches.removeAll()
        matches.removeAll()
        nearbyUsers.removeAll()
        errorMessage = nil
    }
    
    // MARK: - Legacy Compatibility
    
    func findMatches(userAnswers: [AIAnswer]) {
        // For backward compatibility - use real auth instead
        refreshMatchesForCurrentUser()
    }
}

// MARK: - Debug Testing Helper Methods

#if DEBUG
extension MatchEngine {
    
    // Create test users for debugging
    func createTestUsers() async {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("❌ No authenticated user for testing")
            return
        }
        
        // Try to get location from multiple sources
        var userLocation: CLLocation?
        
        // First try LocationManager
        if let location = LocationManager.shared.location {
            userLocation = location
            print("✅ Using LocationManager location: \(location.coordinate)")
        } else {
            // Try to get from current user profile in Firebase
            do {
                let userDoc = try await db.collection("users").document(currentUserId).getDocument()
                if let userData = userDoc.data(),
                   let locationData = userData["location"] as? [String: Any],
                   let lat = locationData["latitude"] as? Double,
                   let lon = locationData["longitude"] as? Double {
                    userLocation = CLLocation(latitude: lat, longitude: lon)
                    print("✅ Using Firebase location: \(lat), \(lon)")
                }
            } catch {
                print("❌ Error getting location from Firebase: \(error)")
            }
        }
        
        guard let location = userLocation else {
            print("❌ No location available from any source for testing")
            return
        }
        
        let testUsers = [
            createTestUser(
                id: "test_user_1",
                name: "Alex",
                lat: location.coordinate.latitude + 0.001, // ~100m away
                lon: location.coordinate.longitude + 0.001,
                interests: ["coffee", "hiking", "books"],
                answers: [
                    ("morning_routine", "What's your ideal morning routine?", "Coffee and reading for 30 minutes"),
                    ("weekend_plans", "Perfect weekend activity?", "Hiking in nature with friends")
                ]
            ),
            createTestUser(
                id: "test_user_2", 
                name: "Maya",
                lat: location.coordinate.latitude - 0.002, // ~200m away
                lon: location.coordinate.longitude + 0.001,
                interests: ["fitness", "music", "travel"],
                answers: [
                    ("workout_style", "Favorite way to stay active?", "Morning yoga and weekend bike rides"),
                    ("travel_dream", "Dream destination?", "Backpacking through Southeast Asia")
                ]
            ),
            createTestUser(
                id: "test_user_3",
                name: "Jordan", 
                lat: location.coordinate.latitude + 0.001,
                lon: location.coordinate.longitude - 0.002,
                interests: ["photography", "coffee", "art"],
                answers: [
                    ("morning_routine", "What's your ideal morning routine?", "Coffee while editing photos from yesterday"),
                    ("creative_outlet", "How do you express creativity?", "Street photography and film development")
                ]
            )
        ]
        
        // Save test users to Firestore
        for testUser in testUsers {
            do {
                try await db.collection("users").document(testUser["uid"] as! String).setData(testUser)
                print("✅ Created test user: \(testUser["firstName"] as! String)")
            } catch {
                print("❌ Failed to create test user: \(error)")
            }
        }
        
        print("🧪 Test users created! Try refreshing your radar.")
    }
    
    private func createTestUser(
        id: String,
        name: String, 
        lat: Double,
        lon: Double,
        interests: [String],
        answers: [(String, String, String)]
    ) -> [String: Any] {
        
        let answersData = answers.map { answer in
            return [
                "questionId": answer.0,
                "questionText": answer.1,
                "answer": answer.2,
                "timestamp": Timestamp(),
                "category": "test"
            ]
        }
        
        return [
            "uid": id,
            "firstName": name,
            "email": "\(name.lowercased())@test.com",
            "age": Int.random(in: 22...35),
            "bio": "Test user for debugging",
            "interests": interests,
            "location": [
                "latitude": lat,
                "longitude": lon
            ],
            "isVisible": true,
            "visibilityRange": 25.0,
            "answers": answersData,
            "lastActive": Timestamp(),
            "createdAt": Timestamp(),
            "hasCompletedOnboarding": true,
            "profileImageURL": ""
        ]
    }
    
    // Debug current user's data
    func debugCurrentUser() async {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("❌ No authenticated user")
            return
        }
        
        do {
            let doc = try await db.collection("users").document(currentUserId).getDocument()
            if let data = doc.data() {
                print("🔍 Current user data:")
                print("- ID: \(currentUserId)")
                print("- Name: \(data["firstName"] as? String ?? "Unknown")")
                print("- Location: \(data["location"] ?? "No location")")
                print("- Visible: \(data["isVisible"] as? Bool ?? false)")
                print("- Interests: \(data["interests"] as? [String] ?? [])")
                print("- Answers: \(data["answers"] as? [[String: Any]] ?? [])")
            }
        } catch {
            print("❌ Error fetching current user: \(error)")
        }
    }
    
    // Debug nearby users query
    func debugNearbyUsersQuery() async {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            print("❌ No authenticated user")
            return
        }
        
        guard let userLocation = LocationManager.shared.location else {
            print("❌ No location available")
            return
        }
        
        print("🔍 Debugging nearby users query...")
        print("- Current location: \(userLocation.coordinate)")
        print("- Search radius: \(maxMatchDistance)km")
        
        let boundingBox = calculateBoundingBox(center: userLocation, radiusKm: maxMatchDistance)
        print("- Bounding box: lat \(boundingBox.minLat) to \(boundingBox.maxLat)")
        
        // First, let's see ALL visible users regardless of location
        do {
            print("🔍 Checking ALL visible users first...")
            let allUsersSnapshot = try await db.collection("users")
                .whereField("isVisible", isEqualTo: true)
                .limit(to: 10)
                .getDocuments()
            
            print("📊 Found \(allUsersSnapshot.documents.count) total visible users:")
            
            for doc in allUsersSnapshot.documents {
                let data = doc.data()
                let name = data["firstName"] as? String ?? "Unknown"
                let visible = data["isVisible"] as? Bool ?? false
                
                // Check different location formats
                let nestedLocation = data["location"] as? [String: Any]
                let nestedLat = nestedLocation?["latitude"] as? Double
                let nestedLon = nestedLocation?["longitude"] as? Double
                
                let directLat = data["latitude"] as? Double
                let directLon = data["longitude"] as? Double
                
                print("  - \(name) (visible: \(visible))")
                print("    - Nested location: lat=\(nestedLat?.description ?? "nil"), lon=\(nestedLon?.description ?? "nil")")
                print("    - Direct location: lat=\(directLat?.description ?? "nil"), lon=\(directLon?.description ?? "nil")")
                
                if doc.documentID == currentUserId {
                    print("    ⭐ This is YOU")
                }
            }
            
            // Now try the nested location query
            print("\n🔍 Trying nested location query...")
            let nestedSnapshot = try await db.collection("users")
                .whereField("isVisible", isEqualTo: true)
                .whereField("location.latitude", isGreaterThan: boundingBox.minLat)
                .whereField("location.latitude", isLessThan: boundingBox.maxLat)
                .getDocuments()
            
            print("📍 Nested query found: \(nestedSnapshot.documents.count) users")
            
            // Try direct location query
            print("\n🔍 Trying direct location query...")
            let directSnapshot = try await db.collection("users")
                .whereField("isVisible", isEqualTo: true)
                .whereField("latitude", isGreaterThan: boundingBox.minLat)
                .whereField("latitude", isLessThan: boundingBox.maxLat)
                .getDocuments()
            
            print("📍 Direct query found: \(directSnapshot.documents.count) users")
            
        } catch {
            print("❌ Error querying nearby users: \(error)")
        }
    }
    
    // Debug existing users in Firebase
    func debugExistingUsers() async {
        print("🔍 Checking existing users in Firebase...")
        
        do {
            let snapshot = try await db.collection("users").getDocuments()
            print("📊 Found \(snapshot.documents.count) total users:")
            
            for (index, document) in snapshot.documents.enumerated() {
                let data = document.data()
                let name = data["firstName"] as? String ?? "Unknown"
                let email = data["email"] as? String ?? "No email"
                let visible = data["isVisible"] as? Bool ?? false
                let hasAnswers = !(data["answers"] as? [[String: Any]] ?? []).isEmpty
                
                // Check location data
                var locationInfo = "No location"
                if let locationData = data["location"] as? [String: Any],
                   let lat = locationData["latitude"] as? Double,
                   let lon = locationData["longitude"] as? Double {
                    locationInfo = "Lat: \(String(format: "%.6f", lat)), Lon: \(String(format: "%.6f", lon))"
                }
                
                print("  \(index + 1). \(name) (\(email))")
                print("     - ID: \(document.documentID)")
                print("     - Visible: \(visible)")
                print("     - Location: \(locationInfo)")
                print("     - Has Answers: \(hasAnswers)")
                print("     - Last Active: \(data["lastActive"] ?? "Never")")
                print("")
            }
            
            if snapshot.documents.count < 2 {
                print("⚠️ Need at least 2 users to test matching. Current count: \(snapshot.documents.count)")
            } else {
                print("✅ Ready to test matching between users!")
            }
            
        } catch {
            print("❌ Error fetching users: \(error)")
        }
    }
    
    // Test matching between two specific users
    func testMatchingBetweenUsers(user1Id: String, user2Id: String) async {
        print("🧪 Testing matching between user1: \(user1Id) and user2: \(user2Id)")
        
        do {
            // Get both users
            let user1Doc = try await db.collection("users").document(user1Id).getDocument()
            let user2Doc = try await db.collection("users").document(user2Id).getDocument()
            
            guard let user1Data = user1Doc.data(),
                  let user2Data = user2Doc.data() else {
                print("❌ Could not find both users")
                return
            }
            
            let user1 = try createUserFromFirestoreData(id: user1Id, data: user1Data)
            let user2 = try createUserFromFirestoreData(id: user2Id, data: user2Data)
            
            print("👤 User 1: \(user1.firstName)")
            print("   - Location: \(user1.latitude ?? 0), \(user1.longitude ?? 0)")
            print("   - Answers: \(user1.aiAnswers.count)")
            print("   - Interests: \(user1.interests)")
            
            print("👤 User 2: \(user2.firstName)")
            print("   - Location: \(user2.latitude ?? 0), \(user2.longitude ?? 0)")
            print("   - Answers: \(user2.aiAnswers.count)")
            print("   - Interests: \(user2.interests)")
            
            // Calculate compatibility
            if !user1.aiAnswers.isEmpty && !user2.aiAnswers.isEmpty {
                let matchResults = await calculateCompatibilityScores(
                    currentUser: user1,
                    potentialMatches: [user2]
                )
                
                if let match = matchResults.first {
                    print("🎯 Compatibility Score: \(Int(match.compatibilityScore * 100))%")
                    print("📊 Match Level: \(match.matchLevel)")
                    print("💡 AI Reasoning: \(match.aiReasoning)")
                } else {
                    print("❌ No compatibility calculated")
                }
            } else {
                print("⚠️ One or both users have no answers for compatibility analysis")
            }
            
        } catch {
            print("❌ Error testing match: \(error)")
        }
    }
}
#endif
