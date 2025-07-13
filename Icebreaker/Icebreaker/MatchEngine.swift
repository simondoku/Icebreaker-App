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
import SwiftUI

// Note: The 'MatchResult' model is now defined in SharedModels.swift.

// MARK: - Match Engine
@MainActor
class MatchEngine: ObservableObject {
    static let shared = MatchEngine()
    
    @Published var currentMatches: [MatchResult] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Add these published properties for compatibility with existing views
    @Published var matches: [MatchResult] = []
    @Published var nearbyUsers: [User] = []
    @Published var isScanning = false
    
    private let db = Firestore.firestore()
    private let aiService = AIService.shared
    private let locationManager = LocationManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Configuration
    private let maxMatchDistance: Double = 50.0 // kilometers
    private let minCompatibilityScore: Double = 0.6
    private let maxMatchesPerSearch = 10
    
    // Make initializer public for compatibility
    init() {
        // Observe location manager changes
        locationManager.$authorizationStatus
            .sink { [weak self] status in
                if status == .authorizedWhenInUse || status == .authorizedAlways {
                    // Location permission granted, retry finding matches if needed
                    if self?.errorMessage == "Location required for matching" {
                        self?.errorMessage = nil
                        // Retry with current user if available
                        self?.retryMatchingWithLocation()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // Keep the shared instance pattern
    static let sharedInstance = MatchEngine()
    
    private func retryMatchingWithLocation() {
        // This will be called when location permission is granted
        // You can store the last user context and retry here
    }
    
    // MARK: - Main Matching Function
    func findMatches(for currentUser: User) async {
        // Check if we have location permission first
        if !locationManager.isLocationPermissionGranted() {
            await MainActor.run {
                self.errorMessage = "Location required for matching"
                // Request location permission
                self.locationManager.requestLocationPermission()
            }
            return
        }
        
        // If we have permission but no current location, try to get it
        if locationManager.location == nil {
            locationManager.startLocationUpdates()
            await MainActor.run {
                self.errorMessage = "Getting your location..."
            }
            return
        }
        
        // Use current location from LocationManager if user location is not available
        let userLocation = currentUser.clLocation ?? locationManager.location
        
        guard let userLocation = userLocation else {
            await MainActor.run {
                self.errorMessage = "Unable to determine your location. Please check your location settings."
            }
            return
        }

        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }

        do {
            // 1. Find nearby users
            let nearbyUsers = try await findNearbyUsers(
                userLocation: userLocation,
                currentUserId: currentUser.id,
                maxDistance: maxMatchDistance
            )

            // 2. Analyze compatibility with each user
            var matchResults: [MatchResult] = []

            for user in nearbyUsers {
                if let matchResult = await analyzeCompatibility(
                    currentUser: currentUser,
                    potentialMatch: user
                ) {
                    matchResults.append(matchResult)
                }
            }

            // 3. Sort by compatibility score and take top matches
            let topMatches = matchResults
                .filter { $0.compatibilityScore >= minCompatibilityScore }
                .sorted { $0.compatibilityScore > $1.compatibilityScore }
                .prefix(maxMatchesPerSearch)

            await MainActor.run {
                self.currentMatches = Array(topMatches)
                self.matches = Array(topMatches) // Also update the compatible matches property
                self.isLoading = false
            }

        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
    
    // MARK: - Convenience method for compatibility with existing code
    func findMatches(userAnswers: [AIAnswer]) {
        // Create a mock user for demonstration purposes
        // In production, this should use the actual current user
        let mockUser = User(
            id: "current_user",
            firstName: "You",
            age: 25,
            bio: "Looking for connections",
            location: "Current Location",
            interests: []
        )
        
        // Set mock location (San Francisco)
        var currentUser = mockUser
        currentUser.latitude = 37.7749
        currentUser.longitude = -122.4194
        currentUser.aiAnswers = userAnswers
        currentUser.isVisible = true
        
        Task {
            await findMatches(for: currentUser)
        }
    }
    
    // MARK: - Find Nearby Users
    private func findNearbyUsers(
        userLocation: CLLocation,
        currentUserId: String,
        maxDistance: Double
    ) async throws -> [User] {
        
        // Simplified query to avoid requiring composite indexes
        // We'll fetch visible users and filter by location in memory
        let snapshot = try await db.collection("users")
            .whereField("isVisible", isEqualTo: true)
            .limit(to: 100) // Limit to reasonable number for memory filtering
            .getDocuments()
        
        var nearbyUsers: [User] = []
        
        for document in snapshot.documents {
            do {
                var user = try document.data(as: User.self)
                
                // Skip current user
                if user.id == currentUserId { continue }
                
                // Calculate exact distance if user has location
                if let userLat = user.latitude, let userLon = user.longitude {
                    let userCLLocation = CLLocation(latitude: userLat, longitude: userLon)
                    let distance = userLocation.distance(from: userCLLocation) / 1000.0 // Convert to km
                    
                    // Check if within actual radius
                    if distance <= maxDistance {
                        user.distanceFromUser = distance
                        nearbyUsers.append(user)
                    }
                }
            } catch {
                print("Error decoding user: \(error)")
            }
        }
        
        // Sort by distance
        nearbyUsers.sort { ($0.distanceFromUser ?? Double.greatestFiniteMagnitude) < ($1.distanceFromUser ?? Double.greatestFiniteMagnitude) }
        
        return nearbyUsers
    }
    
    // MARK: - Analyze Compatibility
    private func analyzeCompatibility(
        currentUser: User,
        potentialMatch: User
    ) async -> MatchResult? {
        
        // Find shared questions/answers
        let sharedAnswers = findSharedAnswers(
            user1Answers: currentUser.aiAnswers,
            user2Answers: potentialMatch.aiAnswers
        )
        
        guard !sharedAnswers.isEmpty else { return nil }
        
        // Analyze each shared answer pair with AI
        var compatibilityScores: [Double] = []
        var analyzedAnswers: [MatchResult.SharedAnswer] = []
        
        for sharedAnswer in sharedAnswers {
            do {
                let analysis = try await analyzeAnswerPair(
                    questionText: sharedAnswer.questionText,
                    answer1: sharedAnswer.userAnswer,
                    answer2: sharedAnswer.matchAnswer
                )
                
                compatibilityScores.append(analysis.score)
                analyzedAnswers.append(MatchResult.SharedAnswer(
                    questionText: sharedAnswer.questionText,
                    userAnswer: sharedAnswer.userAnswer.answer,
                    matchAnswer: sharedAnswer.matchAnswer.answer,
                    compatibility: analysis.score
                ))
            } catch {
                print("AI analysis failed: \(error)")
                // Fallback to basic compatibility score
                let basicScore = calculateBasicCompatibility(
                    answer1: sharedAnswer.userAnswer.answer,
                    answer2: sharedAnswer.matchAnswer.answer
                )
                compatibilityScores.append(basicScore)
                analyzedAnswers.append(MatchResult.SharedAnswer(
                    questionText: sharedAnswer.questionText,
                    userAnswer: sharedAnswer.userAnswer.answer,
                    matchAnswer: sharedAnswer.matchAnswer.answer,
                    compatibility: basicScore
                ))
            }
        }
        
        // Calculate overall compatibility
        let overallCompatibility = compatibilityScores.reduce(0, +) / Double(compatibilityScores.count)
        
        // Generate AI insight
        let insight = await generateMatchInsight(
            compatibility: overallCompatibility,
            sharedAnswers: analyzedAnswers,
            currentUser: currentUser,
            potentialMatch: potentialMatch
        )
        
        return MatchResult(
            user: potentialMatch,
            compatibilityScore: overallCompatibility,
            sharedAnswers: analyzedAnswers,
            aiInsight: insight,
            distance: potentialMatch.distanceFromUser ?? 0,
            matchedAt: Date()
        )
    }
    
    // MARK: - Helper Methods
    private func findSharedAnswers(
        user1Answers: [AIAnswer],
        user2Answers: [AIAnswer]
    ) -> [(questionText: String, userAnswer: AIAnswer, matchAnswer: AIAnswer)] {
        
        var sharedAnswers: [(String, AIAnswer, AIAnswer)] = []
        
        for answer1 in user1Answers {
            for answer2 in user2Answers {
                if answer1.questionId == answer2.questionId {
                    // Find the question text (you might need to store this or fetch it)
                    let questionText = getQuestionText(for: answer1.questionId) ?? "Unknown Question"
                    sharedAnswers.append((questionText, answer1, answer2))
                }
            }
        }
        
        return sharedAnswers
    }
    
    private func getQuestionText(for questionId: String) -> String? {
        // This should fetch from your questions database
        // For now, return a placeholder based on common question patterns
        // In a real app, you'd have a data store for AIQuestions.
        return "What's your favorite way to spend a weekend?"
    }
    
    private func analyzeAnswerPair(
        questionText: String,
        answer1: AIAnswer,
        answer2: AIAnswer
    ) async throws -> CompatibilityAnalysis {
        
        return try await withCheckedThrowingContinuation { continuation in
            aiService.analyzeCompatibility(
                userAnswer: answer1,
                otherAnswer: answer2,
                questionText: questionText
            )
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        break
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                },
                receiveValue: { analysis in
                    continuation.resume(returning: analysis)
                }
            )
            .store(in: &cancellables)
        }
    }
    
    private func calculateBasicCompatibility(answer1: String, answer2: String) -> Double {
        // Basic text similarity fallback
        let words1 = Set(answer1.lowercased().components(separatedBy: .whitespacesAndNewlines))
        let words2 = Set(answer2.lowercased().components(separatedBy: .whitespacesAndNewlines))
        
        let intersection = words1.intersection(words2)
        let union = words1.union(words2)
        
        return union.isEmpty ? 0.0 : Double(intersection.count) / Double(union.count)
    }
    
    private func generateMatchInsight(
        compatibility: Double,
        sharedAnswers: [MatchResult.SharedAnswer],
        currentUser: User,
        potentialMatch: User
    ) async -> String {
        
        do {
            return try await withCheckedThrowingContinuation { continuation in
                aiService.generateMatchInsight(
                    compatibility: compatibility,
                    sharedAnswers: sharedAnswers,
                    userName: currentUser.firstName,
                    matchName: potentialMatch.firstName
                )
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure:
                            continuation.resume(returning: self.generateFallbackInsight(compatibility: compatibility))
                        }
                    },
                    receiveValue: { insight in
                        continuation.resume(returning: insight)
                    }
                )
                .store(in: &cancellables)
            }
        } catch {
            return generateFallbackInsight(compatibility: compatibility)
        }
    }
    
    private func generateFallbackInsight(compatibility: Double) -> String {
        switch compatibility {
        case 0.8...:
            return "You two seem to have a lot in common and similar perspectives!"
        case 0.6..<0.8:
            return "You share some interesting commonalities worth exploring."
        default:
            return "You might have different perspectives that could lead to interesting conversations."
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
    
    // MARK: - Public Interface Methods
    func refreshMatches(for user: User) {
        Task {
            await findMatches(for: user)
        }
    }
    
    func clearMatches() {
        currentMatches.removeAll()
        errorMessage = nil
    }
}
