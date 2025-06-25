//
//  MatchEngine.swift
//  Icebreaker
//
//  Created by Simon Doku on 6/23/25.
//

import Foundation
import CoreLocation
import SwiftUI
import Combine

class MatchEngine: ObservableObject {
    @Published var nearbyUsers: [NearbyUser] = []
    @Published var matches: [MatchResult] = []
    @Published var isScanning = false
    @Published var isAnalyzingMatches = false
    
    private let aiService = AIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - AI-Powered Match Discovery
    func findMatches(userAnswers: [AIAnswer]) {
        isScanning = true
        isAnalyzingMatches = true
        
        // First, get nearby users (in production this would be from Firebase)
        generateNearbyUsers()
        
        // Then analyze compatibility using AI
        analyzeMatchesWithAI(userAnswers: userAnswers)
    }
    
    private func generateNearbyUsers() {
        // Demo nearby users - in production this would come from Firebase with real user data
        nearbyUsers = [
            NearbyUser(
                firstName: "Maya",
                distance: 12,
                location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                answers: generateDemoAnswers(personality: "creative"),
                isActive: false
            ),
            NearbyUser(
                firstName: "Alex",
                distance: 8,
                location: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094),
                answers: generateDemoAnswers(personality: "ambitious"),
                isActive: true
            ),
            NearbyUser(
                firstName: "Jordan",
                distance: 15,
                location: CLLocationCoordinate2D(latitude: 37.7649, longitude: -122.4294),
                answers: generateDemoAnswers(personality: "mindful"),
                isActive: false
            ),
            NearbyUser(
                firstName: "Sam",
                distance: 22,
                location: CLLocationCoordinate2D(latitude: 37.7549, longitude: -122.4394),
                answers: generateDemoAnswers(personality: "active"),
                isActive: true
            )
        ]
        
        isScanning = false
    }
    
    private func analyzeMatchesWithAI(userAnswers: [AIAnswer]) {
        let group = DispatchGroup()
        var tempMatches: [MatchResult] = []
        
        for user in nearbyUsers {
            group.enter()
            
            calculateAICompatibility(userAnswers: userAnswers, with: user) { matchResult in
                tempMatches.append(matchResult)
                group.leave()
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            DispatchQueue.main.async {
                self?.matches = tempMatches.sorted { $0.matchPercentage > $1.matchPercentage }
                self?.isAnalyzingMatches = false
            }
        }
    }
    
    private func calculateAICompatibility(
        userAnswers: [AIAnswer],
        with user: NearbyUser,
        completion: @escaping (MatchResult) -> Void
    ) {
        let sharedQuestions = findSharedQuestions(userAnswers: userAnswers, otherAnswers: user.answers)
        
        if sharedQuestions.isEmpty {
            // No shared questions - use basic compatibility
            let basicMatch = createBasicMatch(with: user)
            completion(basicMatch)
            return
        }
        
        // Analyze each shared answer pair with AI
        let analysisGroup = DispatchGroup()
        var compatibilityScores: [Double] = []
        var sharedAnswers: [MatchResult.SharedAnswer] = []
        
        for (userAnswer, otherAnswer, questionText) in sharedQuestions {
            analysisGroup.enter()
            
            AIQuestionManager().analyzeAnswerCompatibility(
                userAnswer: userAnswer,
                otherAnswer: otherAnswer,
                questionText: questionText
            ) { analysis in
                compatibilityScores.append(analysis.score)
                sharedAnswers.append(MatchResult.SharedAnswer(
                    questionText: questionText,
                    userAnswer: userAnswer.text,
                    matchAnswer: otherAnswer.text,
                    similarity: analysis.score / 100.0
                ))
                analysisGroup.leave()
            }
        }
        
        analysisGroup.notify(queue: .main) {
            let avgCompatibility = compatibilityScores.isEmpty ? 50.0 : compatibilityScores.reduce(0, +) / Double(compatibilityScores.count)
            
            // Generate AI-powered conversation starter and insight
            self.generateAIInsightsAndStarter(
                user: user,
                compatibility: avgCompatibility,
                sharedAnswers: sharedAnswers
            ) { insight, starter in
                let matchResult = MatchResult(
                    user: user,
                    matchPercentage: avgCompatibility,
                    sharedAnswers: sharedAnswers,
                    aiInsight: insight,
                    conversationStarter: starter
                )
                completion(matchResult)
            }
        }
    }
    
    private func generateAIInsightsAndStarter(
        user: NearbyUser,
        compatibility: Double,
        sharedAnswers: [MatchResult.SharedAnswer],
        completion: @escaping (String, String) -> Void
    ) {
        let group = DispatchGroup()
        var insight = "You share some common interests"
        var starter = "Hey \(user.firstName)! Nice to meet someone nearby."
        
        // Generate AI insight
        group.enter()
        aiService.generateMatchInsight(
            compatibility: compatibility,
            sharedAnswers: sharedAnswers,
            userName: "You", // In production, use actual user name
            matchName: user.firstName
        )
        .sink(
            receiveCompletion: { _ in group.leave() },
            receiveValue: { generatedInsight in
                insight = generatedInsight
                group.leave()
            }
        )
        .store(in: &cancellables)
        
        // Generate AI conversation starter
        group.enter()
        aiService.generateConversationStarter(
            sharedAnswers: sharedAnswers,
            userName: "You", // In production, use actual user name
            matchName: user.firstName
        )
        .sink(
            receiveCompletion: { _ in group.leave() },
            receiveValue: { generatedStarter in
                starter = generatedStarter
                group.leave()
            }
        )
        .store(in: &cancellables)
        
        group.notify(queue: .main) {
            completion(insight, starter)
        }
    }
    
    private func findSharedQuestions(userAnswers: [AIAnswer], otherAnswers: [AIAnswer]) -> [(AIAnswer, AIAnswer, String)] {
        var sharedQuestions: [(AIAnswer, AIAnswer, String)] = []
        
        for userAnswer in userAnswers {
            for otherAnswer in otherAnswers {
                if userAnswer.questionId == otherAnswer.questionId {
                    // In production, you'd fetch the actual question text from your database
                    let questionText = getQuestionText(for: userAnswer.questionId)
                    sharedQuestions.append((userAnswer, otherAnswer, questionText))
                }
            }
        }
        
        return sharedQuestions
    }
    
    private func getQuestionText(for questionId: UUID) -> String {
        // In production, this would query your database for the question text
        // For demo purposes, return a sample question
        let sampleQuestions = [
            "What book are you reading right now?",
            "What was the first thing you did this morning?",
            "What's your favorite way to unwind?",
            "What motivates you to stay active?",
            "What's one small habit you're trying to build?",
            "What food did you try for the first time this week?"
        ]
        return sampleQuestions.randomElement() ?? "What's something interesting about you?"
    }
    
    private func createBasicMatch(with user: NearbyUser) -> MatchResult {
        // Fallback when no AI analysis is available
        let compatibility = Double.random(in: 40...70)
        let fallbackAnswers = generateFallbackSharedAnswers(with: user)
        
        return MatchResult(
            user: user,
            matchPercentage: compatibility,
            sharedAnswers: fallbackAnswers,
            aiInsight: "Proximity-based match with potential for connection",
            conversationStarter: "Hey \(user.firstName)! Nice to meet someone nearby. How's your day going?"
        )
    }
    
    private func generateFallbackSharedAnswers(with user: NearbyUser) -> [MatchResult.SharedAnswer] {
        // Generate basic shared interests based on user personality
        switch user.firstName {
        case "Maya":
            return [
                MatchResult.SharedAnswer(
                    questionText: "What book are you reading right now?",
                    userAnswer: "The Artist's Way - exploring creative blocks",
                    matchAnswer: "The Artist's Way - it's changing how I think about creativity",
                    similarity: 0.88
                )
            ]
        case "Alex":
            return [
                MatchResult.SharedAnswer(
                    questionText: "What book are you reading right now?",
                    userAnswer: "Atomic Habits - learning about habit stacking",
                    matchAnswer: "Atomic Habits - the 1% better concept is mind-blowing",
                    similarity: 0.95
                )
            ]
        case "Jordan":
            return [
                MatchResult.SharedAnswer(
                    questionText: "What's your favorite way to unwind?",
                    userAnswer: "Meditation and nature walks",
                    matchAnswer: "Daily meditation practice, love hiking trails",
                    similarity: 0.92
                )
            ]
        case "Sam":
            return [
                MatchResult.SharedAnswer(
                    questionText: "What motivates you to stay active?",
                    userAnswer: "Morning runs give me energy for the day",
                    matchAnswer: "Running is my therapy, especially in the morning",
                    similarity: 0.85
                )
            ]
        default:
            return []
        }
    }
    
    private func generateDemoAnswers(personality: String) -> [AIAnswer] {
        let questionId = UUID()
        
        switch personality {
        case "creative":
            return [
                AIAnswer(questionId: questionId, text: "I love painting watercolors and visiting art galleries on weekends"),
                AIAnswer(questionId: UUID(), text: "Currently reading 'The Artist's Way' - it's changing how I think about creativity")
            ]
        case "ambitious":
            return [
                AIAnswer(questionId: questionId, text: "Reading Atomic Habits and implementing the 1% better principle daily"),
                AIAnswer(questionId: UUID(), text: "Starting my day with coffee and 10 minutes of goal planning")
            ]
        case "mindful":
            return [
                AIAnswer(questionId: questionId, text: "Daily meditation practice and hiking trails are my sanctuary"),
                AIAnswer(questionId: UUID(), text: "Mindful cooking helps me unwind after busy days")
            ]
        case "active":
            return [
                AIAnswer(questionId: questionId, text: "Morning runs are my therapy - especially discovering new trails"),
                AIAnswer(questionId: UUID(), text: "Training for a half marathon while exploring different running routes")
            ]
        default:
            return []
        }
    }
    
    func stopScanning() {
        isScanning = false
        isAnalyzingMatches = false
    }
    
    // MARK: - Match Actions
    func refreshMatches(userAnswers: [AIAnswer]) {
        findMatches(userAnswers: userAnswers)
    }
    
    func getHighQualityMatches() -> [MatchResult] {
        return matches.filter { $0.matchPercentage >= 70 }
    }
    
    func getMatchesInRadius(_ radius: Double) -> [MatchResult] {
        return matches.filter { $0.user.distance <= radius }
    }
}

// MARK: - Enhanced Models
struct NearbyUser: Identifiable {
    let id = UUID()
    let firstName: String
    let distance: Double // in meters
    let location: CLLocationCoordinate2D
    let answers: [AIAnswer]
    let isActive: Bool
    var radarPosition: CGPoint = CGPoint.zero
    
    init(firstName: String, distance: Double, location: CLLocationCoordinate2D, answers: [AIAnswer], isActive: Bool) {
        self.firstName = firstName
        self.distance = distance
        self.location = location
        self.answers = answers
        self.isActive = isActive
        
        // Calculate radar position based on distance and random angle
        let angle = Double.random(in: 0...(2 * .pi))
        let radius = min(distance / 25.0 * 80, 80)
        
        let x = cos(angle) * radius
        let y = sin(angle) * radius
        
        self.radarPosition = CGPoint(x: x, y: y)
    }
    
    var distanceText: String {
        if distance < 1000 {
            return "\(Int(distance))m away"
        } else {
            return String(format: "%.1fkm away", distance / 1000)
        }
    }
}

struct MatchResult: Identifiable {
    let id = UUID()
    let user: NearbyUser
    let matchPercentage: Double
    let sharedAnswers: [SharedAnswer]
    let aiInsight: String
    let conversationStarter: String
    
    struct SharedAnswer {
        let questionText: String
        let userAnswer: String
        let matchAnswer: String
        let similarity: Double
        
        var compatibilityText: String {
            switch similarity {
            case 0.8...1.0: return "Very Similar"
            case 0.6..<0.8: return "Similar"
            case 0.4..<0.6: return "Somewhat Similar"
            default: return "Different Perspective"
            }
        }
    }
    
    var matchLevel: MatchLevel {
        switch matchPercentage {
        case 85...100: return .exceptional
        case 70..<85: return .high
        case 55..<70: return .medium
        default: return .low
        }
    }
    
    enum MatchLevel {
        case exceptional, high, medium, low
        
        var color: Color {
            switch self {
            case .exceptional: return .purple
            case .high: return .green
            case .medium: return .orange
            case .low: return .red
            }
        }
        
        var displayText: String {
            switch self {
            case .exceptional: return "Exceptional Match"
            case .high: return "High Match"
            case .medium: return "Good Match"
            case .low: return "Some Overlap"
            }
        }
        
        var emoji: String {
            switch self {
            case .exceptional: return "✨"
            case .high: return "💚"
            case .medium: return "🧡"
            case .low: return "💭"
            }
        }
    }
}
