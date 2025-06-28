//
//  ChatModel.swift
//  Icebreaker
//
//  Created by Simon Doku on 6/23/25.
//

import Foundation
import SwiftUI

// MARK: - Missing Types for Chat System

// MARK: - Nearby User Type (Legacy compatibility)
typealias NearbyUser = User

struct ChatMessage: Identifiable, Codable {
    var id = UUID()
    let senderId: String
    let senderName: String
    let text: String
    let timestamp: Date
    var isRead: Bool = false
    var isFromCurrentUser: Bool = false // Add missing property
    
    init(senderId: String, senderName: String, text: String, isFromCurrentUser: Bool = false) {
        self.senderId = senderId
        self.senderName = senderName
        self.text = text
        self.timestamp = Date()
        self.isFromCurrentUser = isFromCurrentUser
    }
}

struct Conversation: Identifiable, Codable {
    var id = UUID()
    let participantIds: [String]
    let participantNames: [String]
    var messages: [ChatMessage]
    var lastMessageTimestamp: Date
    var isActive: Bool = true
    
    // Helper to get other participant's name
    func otherParticipantName(currentUserId: String) -> String {
        guard let currentUserIndex = participantIds.firstIndex(of: currentUserId),
              let otherIndex = participantIds.indices.first(where: { $0 != currentUserIndex }) else {
            return "Unknown"
        }
        return participantNames[otherIndex]
    }
    
    // Helper to get last message
    var lastMessage: ChatMessage? {
        messages.last
    }
    
    // Helper to get unread count for a user
    func unreadCount(for userId: String) -> Int {
        messages.filter { $0.senderId != userId && !$0.isRead }.count
    }
}

// Chat Manager
class ChatManager: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var currentUserId: String = "current_user" // This would come from AuthManager
    
    init() {
        loadSampleConversations()
    }
    
    // Create a new conversation
    func startConversation(with user: NearbyUser, aiStarter: String) -> Conversation {
        let conversation = Conversation(
            participantIds: [currentUserId, user.id],
            participantNames: ["You", user.firstName],
            messages: [],
            lastMessageTimestamp: Date()
        )
        
        // Add AI-suggested opening message
        let openingMessage = ChatMessage(
            senderId: currentUserId,
            senderName: "You",
            text: aiStarter
        )
        
        var newConversation = conversation
        newConversation.messages.append(openingMessage)
        newConversation.lastMessageTimestamp = openingMessage.timestamp
        
        conversations.insert(newConversation, at: 0)
        saveConversations()
        
        return newConversation
    }
    
    // Send a message
    func sendMessage(text: String, to conversationId: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        
        let message = ChatMessage(
            senderId: currentUserId,
            senderName: "You",
            text: text
        )
        
        conversations[index].messages.append(message)
        conversations[index].lastMessageTimestamp = message.timestamp
        
        // Move conversation to top
        let conversation = conversations[index]
        conversations.remove(at: index)
        conversations.insert(conversation, at: 0)
        
        saveConversations()
        
        // Simulate response after delay
        simulateResponse(conversationId: conversationId)
    }
    
    // Mark messages as read
    func markAsRead(conversationId: UUID) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        
        for messageIndex in conversations[index].messages.indices {
            if conversations[index].messages[messageIndex].senderId != currentUserId {
                conversations[index].messages[messageIndex].isRead = true
            }
        }
        
        saveConversations()
    }
    
    // Get total unread count
    var totalUnreadCount: Int {
        conversations.reduce(0) { total, conversation in
            total + conversation.unreadCount(for: currentUserId)
        }
    }
    
    // AI-powered message suggestions
    func getMessageSuggestions(for conversation: Conversation) -> [String] {
        guard let lastMessage = conversation.lastMessage else {
            return ["Hey there! 👋", "How's your day going?", "Nice to meet you!"]
        }
        
        let messageText = lastMessage.text.lowercased()
        
        if messageText.contains("book") || messageText.contains("reading") {
            return [
                "What's your favorite genre?",
                "Any book recommendations?",
                "I love getting lost in a good story too!"
            ]
        } else if messageText.contains("coffee") || messageText.contains("cafe") {
            return [
                "What's your go-to coffee order?",
                "Know any good cafes around here?",
                "Coffee enthusiast here too! ☕"
            ]
        } else if messageText.contains("work") || messageText.contains("job") {
            return [
                "What do you do for work?",
                "How do you like your job?",
                "Work can be quite the adventure!"
            ]
        } else {
            return [
                "That's interesting!",
                "Tell me more about that",
                "I'd love to hear your thoughts on that"
            ]
        }
    }
    
    // Simulate receiving a response (for demo)
    private func simulateResponse(conversationId: UUID) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            guard let index = self.conversations.firstIndex(where: { $0.id == conversationId }) else { return }
            
            let otherParticipantName = self.conversations[index].otherParticipantName(currentUserId: self.currentUserId)
            let otherParticipantId = self.conversations[index].participantIds.first { $0 != self.currentUserId } ?? "other"
            
            let responses = [
                "That's really interesting! Tell me more.",
                "I completely agree with that perspective.",
                "Wow, we have so much in common!",
                "That sounds amazing. I'd love to try that sometime.",
                "You seem like someone I'd really enjoy talking to!",
                "I'm so glad we connected through this app."
            ]
            
            let response = ChatMessage(
                senderId: otherParticipantId,
                senderName: otherParticipantName,
                text: responses.randomElement() ?? "Thanks for sharing!"
            )
            
            self.conversations[index].messages.append(response)
            self.conversations[index].lastMessageTimestamp = response.timestamp
            
            self.saveConversations()
        }
    }
    
    // Load sample conversations for demo
    private func loadSampleConversations() {
        let sampleConversation = Conversation(
            participantIds: [currentUserId, "alex_123"],
            participantNames: ["You", "Alex"],
            messages: [
                ChatMessage(senderId: "alex_123", senderName: "Alex", text: "Hey! I saw you're also reading Atomic Habits. Which habit are you working on building right now? 📚"),
                ChatMessage(senderId: currentUserId, senderName: "You", text: "Nice! I'm trying to build a consistent morning routine. The 1% better concept is brilliant! 🌅"),
                ChatMessage(senderId: "alex_123", senderName: "Alex", text: "Same here! I've been doing the coffee + journaling combo for 3 weeks now. What does your morning routine look like?")
            ],
            lastMessageTimestamp: Date().addingTimeInterval(-300) // 5 minutes ago
        )
        
        conversations.append(sampleConversation)
    }
    
    private func saveConversations() {
        if let encoded = try? JSONEncoder().encode(conversations) {
            UserDefaults.standard.set(encoded, forKey: "conversations")
        }
    }
    
    private func loadConversations() {
        if let data = UserDefaults.standard.data(forKey: "conversations"),
           let decoded = try? JSONDecoder().decode([Conversation].self, from: data) {
            conversations = decoded
        }
    }
}
