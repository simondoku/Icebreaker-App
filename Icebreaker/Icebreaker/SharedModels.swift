//
//  SharedModels.swift
//  Icebreaker
//
//  Created by Simon Doku on 7/12/25.
//

import Foundation
import SwiftUI
import CoreLocation

// MARK: - Core User Model
struct User: Identifiable, Codable {
    let id: String
    var firstName: String
    var age: Int
    var bio: String
    var location: String
    var interests: [String]
    var latitude: Double?
    var longitude: Double?
    var distanceFromUser: Double?
    var isOnline: Bool = false
    var isActive: Bool = false
    var lastSeen: Date?
    var aiAnswers: [AIAnswer] = []
    var isVisible: Bool = true
    var profileImageURL: String?
    var createdAt: Date
    
    // Computed CLLocation property
    var clLocation: CLLocation? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocation(latitude: lat, longitude: lon)
    }
    
    // Computed distance property for compatibility
    var distance: Double {
        return distanceFromUser ?? 0.0
    }
    
    // Computed name property for compatibility
    var name: String {
        return firstName
    }
    
    init(id: String, firstName: String, age: Int, bio: String, location: String, interests: [String]) {
        self.id = id
        self.firstName = firstName
        self.age = age
        self.bio = bio
        self.location = location
        self.interests = interests
        self.lastSeen = Date()
        self.createdAt = Date()
        self.profileImageURL = nil
    }
}

// MARK: - AI Answer Model
struct AIAnswer: Identifiable, Codable {
    let id: String
    let questionId: String
    let questionText: String
    let answer: String
    let timestamp: Date
    let category: String?
    let createdAt: Date
    
    // Legacy compatibility property
    var text: String {
        return answer
    }
    
    init(id: String = UUID().uuidString, questionId: String, questionText: String, answer: String, category: String? = nil) {
        self.id = id
        self.questionId = questionId
        self.questionText = questionText
        self.answer = answer
        self.timestamp = Date()
        self.category = category
        self.createdAt = Date()
    }
    
    // Compatibility method for similarity calculation
    func similarity(to other: AIAnswer) -> Double {
        let words1 = Set(answer.lowercased().components(separatedBy: .whitespacesAndNewlines))
        let words2 = Set(other.answer.lowercased().components(separatedBy: .whitespacesAndNewlines))
        
        let commonWords = words1.intersection(words2)
        let totalWords = words1.union(words2)
        
        return totalWords.isEmpty ? 0 : Double(commonWords.count) / Double(totalWords.count)
    }
}

// MARK: - Match Result Model
struct MatchResult: Identifiable, Codable {
    let id: String
    let user: User
    let compatibilityScore: Double
    let sharedAnswers: [SharedAnswer]
    let aiInsight: String
    let aiReasoning: String // Added missing property
    let distance: Double
    let matchedAt: Date
    
    var matchPercentage: Double {
        return compatibilityScore * 100
    }
    
    // Computed conversation starter property
    var conversationStarter: String {
        if !sharedAnswers.isEmpty {
            return "I noticed we both answered '\(sharedAnswers.first!.questionText)' similarly. What do you think about that?"
        } else {
            return "Hey! I saw we have some things in common. How's your day going?"
        }
    }
    
    struct SharedAnswer: Identifiable, Codable {
        let id: String
        let questionText: String
        let userAnswer: String
        let matchAnswer: String
        let compatibility: Double
        
        init(id: String = UUID().uuidString, questionText: String, userAnswer: String, matchAnswer: String, compatibility: Double) {
            self.id = id
            self.questionText = questionText
            self.userAnswer = userAnswer
            self.matchAnswer = matchAnswer
            self.compatibility = compatibility
        }
    }
    
    init(user: User, compatibilityScore: Double, sharedAnswers: [SharedAnswer], aiInsight: String, aiReasoning: String = "", distance: Double, matchedAt: Date = Date()) {
        self.id = UUID().uuidString
        self.user = user
        self.compatibilityScore = compatibilityScore
        self.sharedAnswers = sharedAnswers
        self.aiInsight = aiInsight
        self.aiReasoning = aiReasoning.isEmpty ? aiInsight : aiReasoning // Fallback to aiInsight if aiReasoning is empty
        self.distance = distance
        self.matchedAt = matchedAt
    }
}

// MARK: - Chat Models
struct IcebreakerChatConversation: Identifiable, Codable {
    let id: String
    let matchId: String
    let otherUserName: String
    var lastMessage: String
    var lastMessageTime: Date
    var unreadCount: Int
    var status: ConnectionStatus
    
    init(id: String = UUID().uuidString, matchId: String, otherUserName: String, lastMessage: String, lastMessageTime: Date, unreadCount: Int = 0, status: ConnectionStatus = .noInteraction) {
        self.id = id
        self.matchId = matchId
        self.otherUserName = otherUserName
        self.lastMessage = lastMessage
        self.lastMessageTime = lastMessageTime
        self.unreadCount = unreadCount
        self.status = status
    }
}

// MARK: - Connection Status Extension
enum ConnectionStatus: String, CaseIterable, Codable {
    case noInteraction = "no_interaction"
    case waveSent = "wave_sent"
    case waveReceived = "wave_received"
    case introSent = "intro_sent"
    case introReceived = "intro_received"
    case connected = "connected"
    case passed = "passed"
    case blocked = "blocked"
}

// MARK: - Match Level Enum (single definition)
enum MatchLevel {
    case excellent, great, good, fair, low
    
    var color: Color {
        switch self {
        case .excellent:
            return .green
        case .great:
            return .blue
        case .good:
            return .cyan
        case .fair:
            return .orange
        case .low:
            return .red
        }
    }
}

// MARK: - Match Interaction Model
struct MatchInteraction: Identifiable, Codable {
    let id: String
    let userId: String
    let type: InteractionType
    let timestamp: Date
    let message: String?
    
    enum InteractionType: String, Codable, CaseIterable {
        case wave = "wave"
        case waveReceived = "wave_received"
        case introSent = "intro_sent"
        case introReceived = "intro_received"
        case conversation = "conversation"
        case pass = "pass"
        case block = "block"
    }
    
    init(id: String, userId: String, type: InteractionType, timestamp: Date, message: String? = nil) {
        self.id = id
        self.userId = userId
        self.type = type
        self.timestamp = timestamp
        self.message = message
    }
}

// MARK: - Match Level Extension
extension MatchResult {
    var matchLevel: MatchLevel {
        switch matchPercentage {
        case 90...100:
            return .excellent
        case 80..<90:
            return .great
        case 70..<80:
            return .good
        case 60..<70:
            return .fair
        default:
            return .low
        }
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let waveDelivered = Notification.Name("waveDelivered")
    static let userLocationUpdated = Notification.Name("userLocationUpdated")
    static let introMessageSent = Notification.Name("introMessageSent")
    static let matchAccepted = Notification.Name("matchAccepted")
}

// MARK: - Stat Item Component
struct StatItem: View {
    let number: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(number)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.cyan)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }
}

// MARK: - Real-time Chat Compatibility

enum RealTimeChatConnectionStatus {
    case disconnected
    case connecting
    case connected
    case reconnecting
}

// MARK: - Message Delivery Status Enum
enum MessageDeliveryStatus: String, Codable, CaseIterable {
    case sending = "sending"
    case sent = "sent" 
    case delivered = "delivered"
    case read = "read"
    case failed = "failed"
}

struct RealTimeMessage: Identifiable, Codable {
    let id: String
    let senderId: String
    let text: String
    let timestamp: Date
    var deliveryStatus: MessageDeliveryStatus = .sent
    var isRead: Bool = false
    
    // Add conversationId for compatibility with RealTimeChatManager
    var conversationId: String {
        return id // For now, we'll derive it from the context where it's used
    }
    
    // Computed property to check if message is from current user
    var isFromCurrentUser: Bool {
        return senderId == "current_user"
    }
    
    init(id: String = UUID().uuidString, senderId: String, text: String, timestamp: Date = Date()) {
        self.id = id
        self.senderId = senderId
        self.text = text
        self.timestamp = timestamp
    }
    
    // Mutable initializer for cases where we need to set delivery status
    init(id: String = UUID().uuidString, senderId: String, text: String, timestamp: Date = Date(), deliveryStatus: MessageDeliveryStatus) {
        self.id = id
        self.senderId = senderId
        self.text = text
        self.timestamp = timestamp
        self.deliveryStatus = deliveryStatus
    }
}

struct RealTimeConversation: Identifiable, Codable {
    var id: String
    let participantIds: [String]
    let participantNames: [String]
    var messages: [RealTimeMessage]
    var lastActivity: Date
    var typingUsers: [String]
    var unreadCounts: [String: Int] // userId -> unread count
    
    init(participantIds: [String], participantNames: [String]) {
        self.id = UUID().uuidString
        self.participantIds = participantIds
        self.participantNames = participantNames
        self.messages = []
        self.lastActivity = Date()
        self.typingUsers = []
        self.unreadCounts = [:]
    }
    
    // Computed properties
    var lastMessage: RealTimeMessage? {
        return messages.last
    }
    
    func otherParticipantName(currentUserId: String) -> String {
        guard let currentIndex = participantIds.firstIndex(of: currentUserId) else {
            return participantNames.first ?? "Unknown"
        }
        
        for (index, participantId) in participantIds.enumerated() {
            if participantId != currentUserId && index < participantNames.count {
                return participantNames[index]
            }
        }
        
        return "Unknown"
    }
    
    func unreadCount(for userId: String) -> Int {
        return unreadCounts[userId] ?? 0
    }
    
    func isOtherUserTyping(currentUserId: String) -> Bool {
        return typingUsers.contains { $0 != currentUserId }
    }
}

// MARK: - Real-time Chat UI Components

struct DeliveryStatusIcon: View {
    let status: MessageDeliveryStatus
    
    var body: some View {
        Group {
            switch status {
            case .sending:
                Image(systemName: "clock")
                    .foregroundColor(.white.opacity(0.5))
            case .sent:
                Image(systemName: "checkmark")
                    .foregroundColor(.white.opacity(0.6))
            case .delivered:
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.white.opacity(0.7))
            case .read:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.cyan)
            case .failed:
                Image(systemName: "exclamationmark.circle")
                    .foregroundColor(.red)
            }
        }
        .font(.caption2)
    }
}

struct ConnectionStatusDot: View {
    let status: RealTimeChatConnectionStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .connected:
            return .green
        case .connecting:
            return .yellow
        case .disconnected:
            return .gray
        case .reconnecting:
            return .orange
        }
    }
    
    private var statusText: String {
        switch status {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting..."
        case .disconnected:
            return "Offline"
        case .reconnecting:
            return "Reconnecting..."
        }
    }
}

// MARK: - IcebreakerUser Model (for backward compatibility)
struct IcebreakerUser: Identifiable, Codable {
    let id: String
    var firstName: String
    let email: String
    var isVisible: Bool = true
    
    init(id: String, firstName: String, email: String) {
        self.id = id
        self.firstName = firstName
        self.email = email
    }
}
