//
//  MatchEngine.swift
//  Icebreaker
//
//  Created by Simon Doku on 6/23/25.
//

import Foundation
import CoreLocation
import SwiftUICore

struct NearbyUser: Identifiable {
    let id = UUID()
    let firstName: String
    let distance: Double // in meters
    let location: CLLocationCoordinate2D
    let answers: [AIAnswer]
    let isActive: Bool
    var radarPosition: CGPoint = CGPoint.zero // Make it a stored property instead of computed
    
    init(firstName: String, distance: Double, location: CLLocationCoordinate2D, answers: [AIAnswer], isActive: Bool) {
        self.firstName = firstName
        self.distance = distance
        self.location = location
        self.answers = answers
        self.isActive = isActive
        
        // Calculate initial radar position
        let angle = Double.random(in: 0...(2 * .pi))
        let radius = min(distance / 25.0 * 80, 80) // Scale distance to radar size
        
        let x = cos(angle) * radius
        let y = sin(angle) * radius
        
        self.radarPosition = CGPoint(x: x, y: y)
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
    }
    
    var matchLevel: MatchLevel {
        switch matchPercentage {
        case 80...100: return .high
        case 60..<80: return .medium
        default: return .low
        }
    }
    
    enum MatchLevel {
        case high, medium, low
        
        var color: Color {
            switch self {
            case .high: return .green
            case .medium: return .orange
            case .low: return .red
            }
        }
        
        var displayText: String {
            switch self {
            case .high: return "High Match"
            case .medium: return "Good Match"
            case .low: return "Some Overlap"
            }
        }
    }
}

class MatchEngine: ObservableObject {
    @Published var nearbyUsers: [NearbyUser] = []
    @Published var matches: [MatchResult] = []
    
    // Sample users with realistic answers
    private let sampleUsers: [NearbyUser] = [
        NearbyUser(
            firstName: "Alex",
            distance: 8,
            location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            answers: [
                AIAnswer(questionId: UUID(), text: "Reading Atomic Habits - the 1% better concept is mind-blowing"),
                AIAnswer(questionId: UUID(), text: "Coffee and 10 minutes of journaling"),
                AIAnswer(questionId: UUID(), text: "Building a consistent morning routine")
            ],
            isActive: true
        ),
        NearbyUser(
            firstName: "Sam",
            distance: 15,
            location: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094),
            answers: [
                AIAnswer(questionId: UUID(), text: "Tried this amazing Thai place yesterday"),
                AIAnswer(questionId: UUID(), text: "Meditation and green tea"),
                AIAnswer(questionId: UUID(), text: "Learning guitar")
            ],
            isActive: true
        ),
        NearbyUser(
            firstName: "Jordan",
            distance: 12,
            location: CLLocationCoordinate2D(latitude: 37.7649, longitude: -122.4294),
            answers: [
                AIAnswer(questionId: UUID(), text: "Just finished a 5K run"),
                AIAnswer(questionId: UUID(), text: "Protein smoothie and stretching"),
                AIAnswer(questionId: UUID(), text: "Getting consistent with workouts")
            ],
            isActive: false
        ),
        NearbyUser(
            firstName: "Maya",
            distance: 18,
            location: CLLocationCoordinate2D(latitude: 37.7549, longitude: -122.4394),
            answers: [
                AIAnswer(questionId: UUID(), text: "Sketching in my notebook"),
                AIAnswer(questionId: UUID(), text: "Earl grey tea while reading"),
                AIAnswer(questionId: UUID(), text: "Improving my drawing skills")
            ],
            isActive: true
        )
    ]
    
    func findMatches(userAnswers: [AIAnswer]) {
        nearbyUsers = sampleUsers
        
        matches = nearbyUsers.map { user in
            let matchData = calculateMatch(userAnswers: userAnswers, otherAnswers: user.answers)
            
            return MatchResult(
                user: user,
                matchPercentage: matchData.percentage,
                sharedAnswers: matchData.sharedAnswers,
                aiInsight: generateAIInsight(user: user, matchData: matchData),
                conversationStarter: generateConversationStarter(user: user, matchData: matchData)
            )
        }.sorted { $0.matchPercentage > $1.matchPercentage }
    }
    
    private func calculateMatch(userAnswers: [AIAnswer], otherAnswers: [AIAnswer]) -> (percentage: Double, sharedAnswers: [MatchResult.SharedAnswer]) {
        guard !userAnswers.isEmpty && !otherAnswers.isEmpty else {
            return (0, [])
        }
        
        var sharedAnswers: [MatchResult.SharedAnswer] = []
        var totalSimilarity = 0.0
        
        // Simple keyword matching for demo
        for userAnswer in userAnswers {
            for otherAnswer in otherAnswers {
                let similarity = calculateTextSimilarity(userAnswer.text, otherAnswer.text)
                if similarity > 0.1 { // Threshold for considering it a match
                    sharedAnswers.append(MatchResult.SharedAnswer(
                        questionText: "Recent activity",
                        userAnswer: userAnswer.text,
                        matchAnswer: otherAnswer.text,
                        similarity: similarity
                    ))
                    totalSimilarity += similarity
                }
            }
        }
        
        let percentage = min(totalSimilarity * 100, 95) // Cap at 95% for realism
        return (percentage, sharedAnswers)
    }
    
    private func calculateTextSimilarity(_ text1: String, _ text2: String) -> Double {
        let words1 = Set(text1.lowercased().components(separatedBy: .whitespacesAndNewlines))
        let words2 = Set(text2.lowercased().components(separatedBy: .whitespacesAndNewlines))
        
        let commonWords = words1.intersection(words2)
        let totalWords = words1.union(words2)
        
        // Boost similarity for meaningful keywords
        let meaningfulWords = ["reading", "coffee", "morning", "routine", "habits", "meditation", "exercise", "learning"]
        let meaningfulMatches = commonWords.intersection(Set(meaningfulWords))
        
        let baseSimilarity = totalWords.isEmpty ? 0 : Double(commonWords.count) / Double(totalWords.count)
        let boost = Double(meaningfulMatches.count) * 0.2
        
        return min(baseSimilarity + boost, 1.0)
    }
    
    private func generateAIInsight(user: NearbyUser, matchData: (percentage: Double, sharedAnswers: [MatchResult.SharedAnswer])) -> String {
        if matchData.percentage > 80 {
            return "Strong compatibility based on shared interests in personal development and routines"
        } else if matchData.percentage > 60 {
            return "Good connection potential with some overlapping interests"
        } else {
            return "Different perspectives might lead to interesting conversations"
        }
    }
    
    private func generateConversationStarter(user: NearbyUser, matchData: (percentage: Double, sharedAnswers: [MatchResult.SharedAnswer])) -> String {
        if let topMatch = matchData.sharedAnswers.first {
            if topMatch.userAnswer.contains("coffee") || topMatch.matchAnswer.contains("coffee") {
                return "I see you're also into coffee! What's your favorite morning brew?"
            } else if topMatch.userAnswer.contains("reading") || topMatch.matchAnswer.contains("reading") {
                return "Fellow reader! What book has changed your perspective recently?"
            } else if topMatch.userAnswer.contains("routine") || topMatch.matchAnswer.contains("routine") {
                return "I'm working on building better routines too. What's been most helpful for you?"
            }
        }
        
        return "Hey! I noticed we have some interesting things in common. What brings you to this area?"
    }
}
