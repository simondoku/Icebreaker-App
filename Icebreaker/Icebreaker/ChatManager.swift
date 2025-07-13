//
//  ChatManager.swift
//  Icebreaker
//
//  Created by Simon Doku on 6/25/25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Icebreaker Chat Manager
class IcebreakerChatManager: ObservableObject {
    static let shared = IcebreakerChatManager()
    
    @Published var conversations: [IcebreakerChatConversation] = []
    @Published var currentUserId: String = "current_user"
    @Published var isTyping: [String: Bool] = [:]
    @Published var onlineUsers: Set<String> = []
    
    private let aiService = AIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        loadConversations()
        setupRealtimeListeners()
    }
    
    // MARK: - Public Methods
    func updateConversation(_ conversation: IcebreakerChatConversation) {
        if let index = conversations.firstIndex(where: { $0.id == conversation.id }) {
            conversations[index] = conversation
        } else {
            conversations.append(conversation)
        }
        saveConversations()
    }
    
    func getConversation(for userId: String) -> IcebreakerChatConversation? {
        return conversations.first { $0.matchId == userId }
    }
    
    func deleteConversation(_ conversationId: String) {
        conversations.removeAll { $0.id == conversationId }
        saveConversations()
    }
    
    func markAsRead(_ conversationId: String) {
        if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
            conversations[index].unreadCount = 0
            saveConversations()
        }
    }
    
    // MARK: - Conversation Management
    func startConversation(with user: User, initialMessage: String? = nil) -> IcebreakerChatConversation {
        // Check if conversation already exists
        if let existing = conversations.first(where: { $0.matchId == user.id }) {
            return existing
        }
        
        let conversation = IcebreakerChatConversation(
            id: UUID().uuidString,
            matchId: user.id,
            otherUserName: user.firstName,
            lastMessage: initialMessage ?? "",
            lastMessageTime: Date(),
            unreadCount: 0
        )
        
        conversations.insert(conversation, at: 0)
        saveConversations()
        return conversation
    }
    
    func sendMessage(text: String, to conversationId: String) {
        guard let index = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        
        conversations[index].lastMessage = text
        conversations[index].lastMessageTime = Date()
        
        // Move conversation to top
        let conversation = conversations[index]
        conversations.remove(at: index)
        conversations.insert(conversation, at: 0)
        
        saveConversations()
        
        // Simulate response for demo
        simulateResponse(conversationId: conversationId)
    }
    
    // MARK: - AI-Powered Features
    func generateChatSuggestions(for conversation: IcebreakerChatConversation, partnerUser: User) async -> [String] {
        let fallbackSuggestions = [
            "Hey there! 👋", 
            "How's your day going?", 
            "Nice to meet you!",
            "What's your favorite hobby?",
            "Tell me something interesting about yourself!"
        ]
        return fallbackSuggestions
    }
    
    func generateSmartReply(for conversation: IcebreakerChatConversation, partnerUser: User) async -> String? {
        let suggestions = await generateChatSuggestions(for: conversation, partnerUser: partnerUser)
        return suggestions.first
    }
    
    // MARK: - Real-time Features
    private func setupRealtimeListeners() {
        // Setup Firebase listeners or WebSocket connections
    }
    
    func setTypingStatus(_ isTyping: Bool, for conversationId: String) {
        self.isTyping[conversationId] = isTyping
    }
    
    // MARK: - Computed Properties
    var totalUnreadCount: Int {
        conversations.reduce(0) { $0 + $1.unreadCount }
    }
    
    var activeConversations: [IcebreakerChatConversation] {
        conversations
    }
    
    var recentConversations: [IcebreakerChatConversation] {
        Array(conversations.prefix(10))
    }
    
    // MARK: - Demo Simulation
    private func simulateResponse(conversationId: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            guard let index = self.conversations.firstIndex(where: { $0.id == conversationId }) else { return }
            
            let responses = [
                "That's really interesting! Tell me more.",
                "I completely agree with that perspective.",
                "Wow, we have so much in common!",
                "That sounds amazing. I'd love to try that sometime.",
                "You seem like someone I'd really enjoy talking to!",
                "I'm so glad we connected through this app."
            ]
            
            DispatchQueue.main.async {
                self.conversations[index].lastMessage = responses.randomElement() ?? "Thanks for sharing!"
                self.conversations[index].lastMessageTime = Date()
                self.conversations[index].unreadCount += 1
                
                self.saveConversations()
            }
        }
    }
    
    // MARK: - Data Persistence
    private func saveConversations() {
        if let encoded = try? JSONEncoder().encode(conversations) {
            UserDefaults.standard.set(encoded, forKey: "icebreaker_conversations")
        }
    }
    
    private func loadConversations() {
        if let data = UserDefaults.standard.data(forKey: "icebreaker_conversations"),
           let decoded = try? JSONDecoder().decode([IcebreakerChatConversation].self, from: data) {
            conversations = decoded
        } else {
            loadSampleConversations()
        }
    }
    
    private func loadSampleConversations() {
        let sampleConversation = IcebreakerChatConversation(
            id: UUID().uuidString,
            matchId: "alex_123",
            otherUserName: "Alex",
            lastMessage: "Hey! I saw you're also reading Atomic Habits. Which habit are you working on building right now? 📚",
            lastMessageTime: Date().addingTimeInterval(-300),
            unreadCount: 2
        )
        
        conversations.append(sampleConversation)
        saveConversations()
    }
    
    // MARK: - Conversation Utilities
    func getConversation(with userId: String) -> IcebreakerChatConversation? {
        return conversations.first { $0.matchId == userId }
    }
    
    func searchConversations(query: String) -> [IcebreakerChatConversation] {
        guard !query.isEmpty else { return conversations }
        
        return conversations.filter { conversation in
            conversation.otherUserName.lowercased().contains(query.lowercased()) ||
            conversation.lastMessage.lowercased().contains(query.lowercased())
        }
    }
}