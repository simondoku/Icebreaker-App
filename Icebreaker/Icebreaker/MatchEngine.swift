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

// MARK: - Match Result Models
struct MatchResult: Identifiable {
    let id = UUID()
    let user: User
    let compatibilityScore: Double
    let sharedAnswers: [SharedAnswer]
    let aiInsight: String
    let distance: Double
    let matchedAt: Date
    
    struct SharedAnswer {
        let questionText: String
        let userAnswer: String
        let matchAnswer: String
        let compatibility: Double
    }
    
    // Computed properties for compatibility with existing views
    var matchPercentage: Double {
        return compatibilityScore * 100
    }
    
    var conversationStarter: String {
        return "Hey! I noticed we have some things in common. How's your day going?"
    }
    
    var matchLevel: MatchLevel {
        switch compatibilityScore {
        case 0.8...:
            return MatchLevel.high
        case 0.6..<0.8:
            return MatchLevel.medium
        default:
            return MatchLevel.low
        }
    }
}

// MARK: - Match Level Enum
enum MatchLevel {
    case high, medium, low
    
    var color: Color {
        switch self {
        case .high:
            return .green
        case .medium:
            return .orange
        case .low:
            return .red
        }
    }
}

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
    private var cancellables = Set<AnyCancellable>()
    
    // Configuration
    private let maxMatchDistance: Double = 50.0 // kilometers
    private let minCompatibilityScore: Double = 0.6
    private let maxMatchesPerSearch = 10
    
    // Make initializer public for compatibility
    init() {}
    
    // Keep the shared instance pattern
    static let sharedInstance = MatchEngine()
    
    // MARK: - Main Matching Function
    func findMatches(for currentUser: User) async {
        guard let userLocation = currentUser.clLocation else {
            await MainActor.run {
                self.errorMessage = "Location required for matching"
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
        
        // Calculate bounding box for efficient querying
        let boundingBox = calculateBoundingBox(
            center: userLocation,
            radiusKm: maxDistance
        )
        
        // Query Firebase for users within bounding box
        let snapshot = try await db.collection("users")
            .whereField("isVisible", isEqualTo: true)
            .whereField("latitude", isGreaterThanOrEqualTo: boundingBox.minLat)
            .whereField("latitude", isLessThanOrEqualTo: boundingBox.maxLat)
            .whereField("longitude", isGreaterThanOrEqualTo: boundingBox.minLon)
            .whereField("longitude", isLessThanOrEqualTo: boundingBox.maxLon)
            .getDocuments()
        
        var nearbyUsers: [User] = []
        
        for document in snapshot.documents {
            do {
                var user = try document.data(as: User.self)
                
                // Skip current user
                if user.id == currentUserId { continue }
                
                // Calculate exact distance
                if let userLoc = user.clLocation {
                    let distance = userLocation.distance(from: userLoc) / 1000.0 // Convert to km
                    
                    // Check if within actual radius (not just bounding box)
                    if distance <= maxDistance {
                        user.distanceFromUser = distance
                        nearbyUsers.append(user)
                    }
                }
            } catch {
                print("Error decoding user: \(error)")
            }
        }
        
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
                    userAnswer: sharedAnswer.userAnswer.text,
                    matchAnswer: sharedAnswer.matchAnswer.text,
                    compatibility: analysis.score
                ))
            } catch {
                print("AI analysis failed: \(error)")
                // Fallback to basic compatibility score
                let basicScore = calculateBasicCompatibility(
                    answer1: sharedAnswer.userAnswer.text,
                    answer2: sharedAnswer.matchAnswer.text
                )
                compatibilityScores.append(basicScore)
                analyzedAnswers.append(MatchResult.SharedAnswer(
                    questionText: sharedAnswer.questionText,
                    userAnswer: sharedAnswer.userAnswer.text,
                    matchAnswer: sharedAnswer.matchAnswer.text,
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
                    let questionText = getQuestionText(for: answer1.questionId)
                    sharedAnswers.append((questionText, answer1, answer2))
                }
            }
        }
        
        return sharedAnswers
    }
    
    private func getQuestionText(for questionId: UUID) -> String {
        // This should fetch from your questions database
        // For now, return a placeholder based on common question patterns
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
