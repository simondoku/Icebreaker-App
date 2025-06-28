//
//  ChatManager.swift
//  Icebreaker
//
//  Created by Simon Doku on 6/25/25.
//

import SwiftUI
import Foundation

// MARK: - Chat Models
struct IcebreakerChatConversation: Identifiable {
    let id: String
    let matchId: String
    let otherUserName: String
    var lastMessage: String
    var lastMessageTime: Date
    var unreadCount: Int
}

// MARK: - Chat Manager
class IcebreakerChatManager: ObservableObject {
    @Published var conversations: [IcebreakerChatConversation] = []
    @Published var totalUnreadCount = 0
    
    init() {
        loadSampleConversations()
    }
    
    func loadSampleConversations() {
        // Sample conversations for demo
        conversations = [
            IcebreakerChatConversation(
                id: UUID().uuidString,
                matchId: "match1",
                otherUserName: "Alex",
                lastMessage: "Hey! I saw your answer about travel - I love hiking too!",
                lastMessageTime: Date().addingTimeInterval(-3600),
                unreadCount: 2
            ),
            IcebreakerChatConversation(
                id: UUID().uuidString,
                matchId: "match2", 
                otherUserName: "Sam",
                lastMessage: "That's such an interesting perspective on coffee...",
                lastMessageTime: Date().addingTimeInterval(-7200),
                unreadCount: 0
            )
        ]
        
        updateUnreadCount()
    }
    
    func updateUnreadCount() {
        totalUnreadCount = conversations.reduce(0) { $0 + $1.unreadCount }
    }
    
    func markAsRead(_ conversationId: String) {
        if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
            conversations[index].unreadCount = 0
            updateUnreadCount()
        }
    }
    
    func updateConversation(conversationId: String, with message: String) {
        if let index = conversations.firstIndex(where: { $0.id == conversationId }) {
            conversations[index].lastMessage = message
            conversations[index].lastMessageTime = Date()
            
            // Move conversation to top
            let conversation = conversations[index]
            conversations.remove(at: index)
            conversations.insert(conversation, at: 0)
            
            updateUnreadCount()
        }
    }
}