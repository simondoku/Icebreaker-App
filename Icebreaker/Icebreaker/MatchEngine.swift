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
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Demo Data (Replace with Firebase in production)
    func findMatches(userAnswers: [AIAnswer]) {
        isScanning = true
        
        // Simulate API call
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.generateDemoMatches()
            self.isScanning = false
        }
    }
    
    private func generateDemoMatches() {
        // Demo nearby users - in production this would come from Firebase
        nearbyUsers = [
            NearbyUser(
                firstName: "Maya",
                distance: 12,
                location: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                answers: [],
                isActive: false
            ),
            NearbyUser(
                firstName: "Alex",
                distance: 8,
                location: CLLocationCoordinate2D(latitude: 37.7849, longitude: -122.4094),
                answers: [],
                isActive: true
            ),
            NearbyUser(
                firstName: "Jordan",
                distance: 15,
                location: CLLocationCoordinate2D(latitude: 37.7649, longitude: -122.4294),
                answers: [],
                isActive: false
            ),
            NearbyUser(
                firstName: "Sam",
                distance: 22,
                location: CLLocationCoordinate2D(latitude: 37.7549, longitude: -122.4394),
                answers: [],
                isActive: true
            )
        ]
        
        // Generate matches from nearby users
        matches = nearbyUsers.map { user in
            let compatibility = calculateCompatibility(with: user)
            let sharedAnswers = generateSharedAnswers(with: user)
            
            return MatchResult(
                user: user,
                matchPercentage: compatibility,
                sharedAnswers: sharedAnswers,
                aiInsight: generateAIInsight(user: user, compatibility: compatibility),
                conversationStarter: generateConversationStarter(user: user)
            )
        }.sorted { $0.matchPercentage > $1.matchPercentage }
    }
    
    private func calculateCompatibility(with user: NearbyUser) -> Double {
        // Demo compatibility calculation
        switch user.firstName {
        case "Alex": return 92.0
        case "Jordan": return 88.0
        case "Sam": return 76.0
        case "Maya": return 45.0
        default: return Double.random(in: 40...95)
        }
    }
    
    private func generateSharedAnswers(with user: NearbyUser) -> [MatchResult.SharedAnswer] {
        // Demo shared answers based on user
        switch user.firstName {
        case "Alex":
            return [
                MatchResult.SharedAnswer(
                    questionText: "What book are you reading right now?",
                    userAnswer: "Atomic Habits - learning about habit stacking",
                    matchAnswer: "Atomic Habits - the 1% better concept is mind-blowing",
                    similarity: 0.95
                ),
                MatchResult.SharedAnswer(
                    questionText: "What was the first thing you did this morning?",
                    userAnswer: "Coffee + 10 minutes of journaling",
                    matchAnswer: "Made my coffee and wrote in my gratitude journal",
                    similarity: 0.88
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
    
    private func generateAIInsight(user: NearbyUser, compatibility: Double) -> String {
        if compatibility > 85 {
            return "Strong compatibility based on shared interests and values"
        } else if compatibility > 70 {
            return "Good connection potential with overlapping interests"
        } else if compatibility > 50 {
            return "Some shared elements that could lead to interesting conversations"
        } else {
            return "Different perspectives that might create engaging discussions"
        }
    }
    
    private func generateConversationStarter(user: NearbyUser) -> String {
        switch user.firstName {
        case "Alex":
            return "Hey! I saw you're also reading Atomic Habits. Which habit are you working on building right now? I'm trying to get consistent with my morning routine!"
        case "Jordan":
            return "Hi there! I noticed we both practice meditation. Have you tried any hiking meditation spots around here?"
        case "Sam":
            return "Hello! Fellow morning runner here! What's your favorite route in the area?"
        case "Maya":
            return "Hey! I see we're both interested in fitness. What's your favorite workout these days?"
        default:
            return "Hey \(user.firstName)! Nice to meet someone nearby. How's your day going?"
        }
    }
    
    func stopScanning() {
        isScanning = false
    }
}

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
