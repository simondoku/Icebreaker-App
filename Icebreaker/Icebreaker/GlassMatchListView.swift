//
//  MatchListView.swift
//  Icebreaker
//
//  Created by Simon Doku on 6/23/25.
//
import SwiftUI
import CoreLocation

struct GlassMatchListView: View {
    @StateObject private var matchEngine = MatchEngine()
    @EnvironmentObject var questionManager: AIQuestionManager
    
    @State private var selectedMatch: MatchResult?
    @State private var showingUserDetails = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Smart Matches")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("AI found 4 great connections nearby")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 20)
                    
                    // Today's Best Match Card
                    TodaysBestMatchCard()
                    
                    // Match Cards
                    VStack(spacing: 16) {
                        SmartMatchCard(
                            name: "Alex",
                            matchPercentage: 92,
                            avatar: "A",
                            avatarGradient: [.red, .green],
                            connectionType: "📚 Reading Connection",
                            connectionText: "Both reading \"Atomic Habits\" and love morning coffee rituals",
                            isActive: true,
                            activeText: "Active now",
                            distance: "8m away"
                        ) {
                            selectedMatch = createAlexMatch()
                            showingUserDetails = true
                        }
                        
                        SmartMatchCard(
                            name: "Jordan",
                            matchPercentage: 88,
                            avatar: "J", 
                            avatarGradient: [.purple, .blue],
                            connectionType: "🧘 Mindfulness Match",
                            connectionText: "Both practicing meditation and exploring philosophy books",
                            isActive: false,
                            activeText: "Active 5m ago",
                            distance: "12m away"
                        ) {
                            // Handle tap
                        }
                        
                        SmartMatchCard(
                            name: "Sam",
                            matchPercentage: 76,
                            avatar: "S",
                            avatarGradient: [.cyan, .green],
                            connectionType: "🏃 Fitness Connection",
                            connectionText: "Both enjoy morning runs and healthy lifestyle choices",
                            isActive: true,
                            activeText: "Active now",
                            distance: "15m away"
                        ) {
                            // Handle tap
                        }
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
            }
            .navigationBarHidden(true)
            .onAppear {
                updateMatches()
            }
            .sheet(isPresented: $showingUserDetails) {
                if let match = selectedMatch {
                    SimpleUserDetailView(match: match)
                }
            }
        }
    }
    
    private func updateMatches() {
        matchEngine.findMatches(userAnswers: questionManager.userAnswers)
    }
    
    private func createAlexMatch() -> MatchResult {
        let alexUser = User(
            id: UUID().uuidString,
            firstName: "Alex Chen", 
            age: 28,
            bio: "Love reading and building good habits",
            location: "San Francisco",
            profileImageURL: nil,
            interests: ["reading", "productivity", "coffee"],
            createdAt: Date()
        )
        
        // Set location coordinates
        var updatedUser = alexUser
        updatedUser.latitude = 37.7749
        updatedUser.longitude = -122.4194
        updatedUser.distanceFromUser = 8.0
        updatedUser.isOnline = true
        updatedUser.lastSeen = Date()
        updatedUser.isVisible = true
        
        // Add AI answers
        updatedUser.aiAnswers = [
            AIAnswer(questionId: UUID(), text: "Atomic Habits - the 1% better concept is mind-blowing"),
            AIAnswer(questionId: UUID(), text: "Made my coffee and wrote in my gratitude journal"),
            AIAnswer(questionId: UUID(), text: "Building better daily systems and habits")
        ]
        
        let sharedAnswers = [
            MatchResult.SharedAnswer(
                questionText: "What book are you reading right now?",
                userAnswer: "Atomic Habits - learning about habit stacking",
                matchAnswer: "Atomic Habits - the 1% better concept is mind-blowing",
                compatibility: 0.95
            ),
            MatchResult.SharedAnswer(
                questionText: "What was the first thing you did this morning?",
                userAnswer: "Coffee + 10 minutes of journaling",
                matchAnswer: "Made my coffee and wrote in my gratitude journal",
                compatibility: 0.88
            ),
            MatchResult.SharedAnswer(
                questionText: "What's one thing you want to improve about yourself?",
                userAnswer: "Being more consistent with my routines",
                matchAnswer: "Building better daily systems and habits",
                compatibility: 0.82
            )
        ]
        
        return MatchResult(
            user: updatedUser,
            compatibilityScore: 0.92,
            sharedAnswers: sharedAnswers,
            aiInsight: "Strong compatibility based on shared interests in personal development and routines",
            distance: 8.0,
            matchedAt: Date()
        )
    }
}

struct TodaysBestMatchCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "target")
                    .foregroundColor(.red)
                    .font(.title2)
                
                Text("Today's Best Match")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.cyan)
                
                Spacer()
            }
            
            Text("Alex has 92% compatibility based on shared reading interests, morning routines, and productivity mindset. Perfect conversation starter ready!")
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.leading)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 2)
                )
        )
    }
}

struct SmartMatchCard: View {
    let name: String
    let matchPercentage: Int
    let avatar: String
    let avatarGradient: [Color]
    let connectionType: String
    let connectionText: String
    let isActive: Bool
    let activeText: String
    let distance: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    // Avatar with match percentage badge
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: avatarGradient,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                        
                        Text(avatar)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                        
                        // Match percentage badge
                        VStack {
                            HStack {
                                Spacer()
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Text("\(matchPercentage)%")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    )
                                    .offset(x: 8, y: -8)
                            }
                            Spacer()
                        }
                        .frame(width: 80, height: 80)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        // Name
                        Text(name)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        // Connection type card
                        VStack(alignment: .leading, spacing: 8) {
                            Text(connectionType)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                            
                            Text(connectionText)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.leading)
                        }
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                )
                        )
                        
                        // Status and distance
                        HStack(spacing: 12) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(isActive ? .green : .orange)
                                    .frame(width: 8, height: 8)
                                
                                Text(activeText)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Text(distance)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                            
                            Spacer()
                        }
                    }
                    
                    Spacer()
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Empty state
struct EmptyMatchesView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text("🎯")
                .font(.system(size: 80))
            
            Text("No matches yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                Text("Answer more AI questions to improve your matches!")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                
                Text("Make sure location services are enabled.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
}

// Filter View (simple for now)
struct FilterView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Filter Options")
                    .font(.title2)
                    .padding()
                
                Text("Coming soon! You'll be able to filter by:")
                    .foregroundColor(.gray)
                    .padding()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("• Match percentage")
                    Text("• Distance range")
                    Text("• Activity status")
                    Text("• Question categories")
                }
                .foregroundColor(.secondary)
                .padding()
                
                Spacer()
            }
            .navigationTitle("Filters")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
struct SimpleUserDetailView: View {
    let match: MatchResult
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // User Profile Header with large avatar
                    VStack(spacing: 16) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.red, .green],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .overlay(
                                Text("A")
                                    .font(.system(size: 48, weight: .bold))
                                    .foregroundColor(.white)
                            )
                        
                        Text(match.user.firstName)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .padding(.top, 20)
                    
                    // AI Connection Analysis
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("🧠 AI Connection Analysis")
                                .font(.title2)
                                .fontWeight(.medium)
                                .foregroundColor(.cyan)
                            
                            Spacer()
                            
                            Text("\(Int(match.matchPercentage))% Match")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.cyan.opacity(0.3), lineWidth: 2)
                            )
                    )
                    
                    // Shared Answers Section
                    VStack(spacing: 16) {
                        ForEach(Array(match.sharedAnswers.enumerated()), id: \.offset) { index, sharedAnswer in
                            SharedAnswerCard(sharedAnswer: sharedAnswer)
                        }
                    }
                    
                    // Perfect Conversation Starter
                    VStack(alignment: .leading, spacing: 12) {
                        Text("💡 Perfect Conversation Starter")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                        
                        Text(match.conversationStarter)
                            .font(.body)
                            .foregroundColor(.white.opacity(0.9))
                            .multilineTextAlignment(.leading)
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.green.opacity(0.4), lineWidth: 2)
                            )
                    )
                    
                    // Stats Section
                    HStack(spacing: 40) {
                        StatColumn(number: "\(Int(match.user.distance))m", label: "Distance", color: .cyan)
                        StatColumn(number: "3", label: "Shared Topics", color: .cyan)
                        StatColumn(number: "7", label: "Days Active", color: .cyan)
                    }
                    .padding(.vertical, 16)
                    
                    // Status Bar
                    HStack(spacing: 12) {
                        Circle()
                            .fill(.green)
                            .frame(width: 12, height: 12)
                        
                        Text("Active now • Answered 2 questions today")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                        
                        Spacer()
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
                            )
                    )
                    
                    // Action Buttons
                    HStack(spacing: 16) {
                        Button("👋 Wave") {
                            dismiss()
                        }
                        .font(.headline)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                        
                        Button("💬 Start Chat") {
                            dismiss()
                        }
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .cyan],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
            }
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("←") {
                        dismiss()
                    }
                    .font(.title2)
                    .foregroundColor(.white)
                }
            }
        }
    }
}

struct SharedAnswerCard: View {
    let sharedAnswer: MatchResult.SharedAnswer
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Question with emoji
            HStack(spacing: 8) {
                Text(getQuestionEmoji())
                    .font(.title3)
                
                Text(sharedAnswer.questionText)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
            }
            
            // Answers side by side
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("You")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("\"\(sharedAnswer.userAnswer)\"")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Alex")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("\"\(sharedAnswer.matchAnswer)\"")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private func getQuestionEmoji() -> String {
        if sharedAnswer.questionText.contains("book") {
            return "📚"
        } else if sharedAnswer.questionText.contains("morning") {
            return "☕"
        } else if sharedAnswer.questionText.contains("improve") {
            return "🎯"
        }
        return "💭"
    }
}

struct StatColumn: View {
    let number: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(number)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

#Preview {
    GlassMatchListView()
        .environmentObject(AIQuestionManager())
}
