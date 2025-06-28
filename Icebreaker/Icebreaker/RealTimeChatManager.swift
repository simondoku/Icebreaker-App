//
//  RealTimeChatManager.swift
//  Icebreaker
//
//  Created by Simon Doku on 6/25/25.
//

import Foundation
import Combine
import SwiftUI

// MARK: - Message Models

enum MessageType: String, Codable, CaseIterable {
    case text = "text"
    case icebreaker = "icebreaker"
    case image = "image"
    case emoji = "emoji"
    case system = "system"
}

enum MessageDeliveryStatus: String, Codable {
    case sending = "sending"
    case sent = "sent"
    case delivered = "delivered"
    case read = "read"
    case failed = "failed"
}

struct RealTimeMessage: Identifiable, Codable {
    let id: String
    let conversationId: String
    let senderId: String
    let senderName: String
    let text: String
    let type: MessageType
    let timestamp: Date
    var deliveryStatus: MessageDeliveryStatus
    var isRead: Bool
    var metadata: [String: String]?
    
    init(
        conversationId: String,
        senderId: String,
        senderName: String,
        text: String,
        type: MessageType = .text
    ) {
        self.id = UUID().uuidString
        self.conversationId = conversationId
        self.senderId = senderId
        self.senderName = senderName
        self.text = text
        self.type = type
        self.timestamp = Date()
        self.deliveryStatus = .sending
        self.isRead = false
    }
}

// MARK: - Conversation Models

struct RealTimeConversation: Identifiable, Codable {
    let id: String
    let participantIds: [String]
    let participantNames: [String]
    var messages: [RealTimeMessage]
    var lastActivity: Date
    var isActive: Bool
    var isMuted: Bool
    var isTyping: [String: Bool] // userId -> isTyping
    
    init(participantIds: [String], participantNames: [String]) {
        self.id = UUID().uuidString
        self.participantIds = participantIds
        self.participantNames = participantNames
        self.messages = []
        self.lastActivity = Date()
        self.isActive = true
        self.isMuted = false
        self.isTyping = [:]
    }
    
    // Helper methods
    func otherParticipantName(currentUserId: String) -> String {
        guard let currentUserIndex = participantIds.firstIndex(of: currentUserId),
              let otherIndex = participantIds.indices.first(where: { $0 != currentUserIndex }) else {
            return "Unknown"
        }
        return participantNames[otherIndex]
    }
    
    func otherParticipantId(currentUserId: String) -> String? {
        return participantIds.first { $0 != currentUserId }
    }
    
    var lastMessage: RealTimeMessage? {
        return messages.last
    }
    
    func unreadCount(for userId: String) -> Int {
        return messages.filter { $0.senderId != userId && !$0.isRead }.count
    }
    
    func isOtherUserTyping(currentUserId: String) -> Bool {
        return isTyping.contains { key, value in
            key != currentUserId && value
        }
    }
}

// MARK: - Connection Status

enum ConnectionStatus {
    case disconnected
    case connecting
    case connected
    case reconnecting
}

// MARK: - Real-Time Chat Manager

class RealTimeChatManager: ObservableObject {
    static let shared = RealTimeChatManager()
    
    // Published properties for UI updates
    @Published var conversations: [RealTimeConversation] = []
    @Published var activeConversation: RealTimeConversation?
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var isTyping: Bool = false
    
    // Private properties
    private let currentUserId: String
    private let persistenceManager = ChatPersistenceManager()
    private var cancellables = Set<AnyCancellable>()
    private var typingTimer: Timer?
    private var autoSaveTimer: Timer?
    private var reconnectionTimer: Timer?
    
    // Real-time simulation
    private var messageQueue: [RealTimeMessage] = []
    private var isProcessingQueue = false
    
    init(currentUserId: String = "current_user") {
        self.currentUserId = currentUserId
        setupRealTimeChat()
    }
    
    // MARK: - Setup & Initialization
    
    private func setupRealTimeChat() {
        loadConversations()
        startConnectionSimulation()
        setupAutoSave()
        setupMessageProcessing()
    }
    
    private func setupMessageProcessing() {
        // Process message queue every 500ms
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.processMessageQueue()
        }
    }
    
    // MARK: - Public Methods
    
    func sendMessage(_ text: String, to conversationId: String, type: MessageType = .text) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let message = RealTimeMessage(
            conversationId: conversationId,
            senderId: currentUserId,
            senderName: "You",
            text: text,
            type: type
        )
        
        addMessageToConversation(message)
        simulateMessageDelivery(messageId: message.id, conversationId: conversationId)
        
        // Stop typing indicator
        setTypingStatus(false, in: conversationId)
        
        // Simulate reply from other user (for demo)
        simulateReply(to: conversationId, after: 2.0)
    }
    
    func markMessagesAsRead(in conversationId: String) {
        guard let conversationIndex = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        
        for messageIndex in conversations[conversationIndex].messages.indices {
            if conversations[conversationIndex].messages[messageIndex].senderId != currentUserId {
                conversations[conversationIndex].messages[messageIndex].isRead = true
                conversations[conversationIndex].messages[messageIndex].deliveryStatus = .read
            }
        }
        
        updateActiveConversation(conversationId)
        saveConversations()
    }
    
    func setTypingStatus(_ isTyping: Bool, in conversationId: String) {
        guard let conversationIndex = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        
        conversations[conversationIndex].isTyping[currentUserId] = isTyping
        updateActiveConversation(conversationId)
        
        if isTyping {
            // Reset typing timer
            typingTimer?.invalidate()
            typingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                self?.setTypingStatus(false, in: conversationId)
            }
        } else {
            typingTimer?.invalidate()
        }
    }
    
    func createConversation(with userId: String, userName: String) -> RealTimeConversation {
        let conversation = RealTimeConversation(
            participantIds: [currentUserId, userId],
            participantNames: ["You", userName]
        )
        
        conversations.append(conversation)
        saveConversations()
        
        return conversation
    }
    
    func deleteConversation(_ conversationId: String) {
        conversations.removeAll { $0.id == conversationId }
        
        if activeConversation?.id == conversationId {
            activeConversation = nil
        }
        
        saveConversations()
    }
    
    func setActiveConversation(_ conversation: RealTimeConversation?) {
        activeConversation = conversation
        
        if let conversation = conversation {
            markMessagesAsRead(in: conversation.id)
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func addMessageToConversation(_ message: RealTimeMessage) {
        guard let conversationIndex = conversations.firstIndex(where: { $0.id == message.conversationId }) else { return }
        
        conversations[conversationIndex].messages.append(message)
        conversations[conversationIndex].lastActivity = message.timestamp
        
        updateActiveConversation(message.conversationId)
        saveConversations()
    }
    
    private func updateActiveConversation(_ conversationId: String) {
        if activeConversation?.id == conversationId {
            activeConversation = conversations.first { $0.id == conversationId }
        }
    }
    
    private func simulateMessageDelivery(messageId: String, conversationId: String) {
        // Simulate network delay and delivery status progression
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.updateMessageStatus(messageId: messageId, conversationId: conversationId, status: .sent)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.updateMessageStatus(messageId: messageId, conversationId: conversationId, status: .delivered)
        }
        
        // Sometimes simulate read status
        if Bool.random() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 3.0...10.0)) { [weak self] in
                self?.updateMessageStatus(messageId: messageId, conversationId: conversationId, status: .read)
            }
        }
    }
    
    private func updateMessageStatus(messageId: String, conversationId: String, status: MessageDeliveryStatus) {
        guard let conversationIndex = conversations.firstIndex(where: { $0.id == conversationId }),
              let messageIndex = conversations[conversationIndex].messages.firstIndex(where: { $0.id == messageId }) else { return }
        
        conversations[conversationIndex].messages[messageIndex].deliveryStatus = status
        updateActiveConversation(conversationId)
        saveConversations()
    }
    
    private func simulateReply(to conversationId: String, after delay: TimeInterval) {
        guard let conversation = conversations.first(where: { $0.id == conversationId }),
              let otherUserId = conversation.otherParticipantId(currentUserId: currentUserId),
              let otherUserName = conversation.otherParticipantName(currentUserId: currentUserId) != "Unknown" ? conversation.otherParticipantName(currentUserId: currentUserId) : nil else { return }
        
        // Simulate typing indicator
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self,
                  let conversationIndex = self.conversations.firstIndex(where: { $0.id == conversationId }) else { return }
            
            self.conversations[conversationIndex].isTyping[otherUserId] = true
            self.updateActiveConversation(conversationId)
            
            // Send reply after typing
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 1.0...3.0)) { [weak self] in
                self?.sendSimulatedReply(conversationId: conversationId, senderId: otherUserId, senderName: otherUserName)
            }
        }
    }
    
    private func sendSimulatedReply(conversationId: String, senderId: String, senderName: String) {
        guard let conversationIndex = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        
        // Stop typing
        conversations[conversationIndex].isTyping[senderId] = false
        
        let replies = getContextualResponses(for: conversations[conversationIndex].lastMessage, conversation: conversations[conversationIndex])
        let replyText = replies.randomElement() ?? "That's interesting!"
        
        let replyMessage = RealTimeMessage(
            conversationId: conversationId,
            senderId: senderId,
            senderName: senderName,
            text: replyText
        )
        
        var message = replyMessage
        message.deliveryStatus = .delivered
        
        addMessageToConversation(message)
    }
    
    private func getContextualResponses(for lastMessage: RealTimeMessage?, conversation: RealTimeConversation) -> [String] {
        guard let lastMessage = lastMessage else {
            return ["Hey! 👋", "How's your day going?", "Nice to meet you!"]
        }
        
        let text = lastMessage.text.lowercased()
        
        if text.contains("book") || text.contains("read") {
            return [
                "What genre do you usually enjoy?",
                "I love reading too! Any recommendations?",
                "That book sounds fascinating!",
                "I've been meaning to read that one!"
            ]
        } else if text.contains("coffee") || text.contains("café") {
            return [
                "I'm a coffee lover too! ☕",
                "What's your favorite coffee shop?",
                "Do you prefer espresso or pour-over?",
                "Coffee dates are the best!"
            ]
        } else if text.contains("travel") || text.contains("trip") {
            return [
                "Where's your dream destination?",
                "Travel stories are the best! ✈️",
                "I love exploring new places too!",
                "Any travel tips to share?"
            ]
        } else if text.contains("music") || text.contains("song") {
            return [
                "What's your favorite genre? 🎵",
                "I love discovering new music!",
                "Do you play any instruments?",
                "Music connects people so well!"
            ]
        } else {
            return [
                "That's really interesting!",
                "Tell me more about that!",
                "I love your perspective on this!",
                "We have so much to talk about!",
                "That sounds amazing!",
                "I couldn't agree more!"
            ]
        }
    }
    
    private func processMessageQueue() {
        guard !isProcessingQueue && !messageQueue.isEmpty else { return }
        
        isProcessingQueue = true
        let message = messageQueue.removeFirst()
        
        // Process the message (simulate network delay)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.addMessageToConversation(message)
            self?.isProcessingQueue = false
        }
    }
    
    private func startConnectionSimulation() {
        connectionStatus = .connecting
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.connectionStatus = .connected
        }
        
        // Simulate occasional disconnections
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            if Bool.random() && self?.connectionStatus == .connected {
                self?.connectionStatus = .reconnecting
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self?.connectionStatus = .connected
                }
            }
        }
    }
    
    private func setupAutoSave() {
        // Auto-save every 10 seconds
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.saveConversations()
        }
    }
    
    // MARK: - Persistence
    
    private func saveConversations() {
        persistenceManager.saveConversations(conversations)
    }
    
    private func loadConversations() {
        conversations = persistenceManager.loadConversations()
        
        // Load sample conversation if none exist
        if conversations.isEmpty {
            loadSampleConversation()
        }
    }
    
    private func loadSampleConversation() {
        let sampleConversation = RealTimeConversation(
            participantIds: [currentUserId, "alex_demo_123"],
            participantNames: ["You", "Alex"]
        )
        
        var conversation = sampleConversation
        
        // Add sample messages
        let messages = [
            RealTimeMessage(
                conversationId: conversation.id,
                senderId: "alex_demo_123",
                senderName: "Alex",
                text: "Hey! I saw you're also into reading. What's the last book that completely changed your perspective? 📚",
                type: .icebreaker
            ),
            RealTimeMessage(
                conversationId: conversation.id,
                senderId: currentUserId,
                senderName: "You",
                text: "Hi Alex! I just finished 'Atomic Habits' and it's been a game-changer for my daily routine. The 1% better concept is so powerful! What about you?",
                type: .text
            ),
            RealTimeMessage(
                conversationId: conversation.id,
                senderId: "alex_demo_123",
                senderName: "Alex",
                text: "That's amazing! I love that book too. I've been working on the 'habit stacking' technique for my morning routine. Have you tried implementing any specific habits from it?",
                type: .text
            )
        ]
        
        conversation.messages = messages
        conversation.lastActivity = messages.last?.timestamp ?? Date()
        
        // Set delivery status for demo messages
        for i in conversation.messages.indices {
            conversation.messages[i].deliveryStatus = .read
            conversation.messages[i].isRead = true
        }
        
        conversations.append(conversation)
        saveConversations()
    }
    
    // MARK: - Public Getters
    
    var totalUnreadCount: Int {
        return conversations.reduce(0) { total, conversation in
            total + conversation.unreadCount(for: currentUserId)
        }
    }
    
    var activeConversations: [RealTimeConversation] {
        return conversations.filter { $0.isActive }.sorted { $0.lastActivity > $1.lastActivity }
    }
    
    func getConversation(by id: String) -> RealTimeConversation? {
        return conversations.first { $0.id == id }
    }
    
    func getMessageSuggestions(for conversation: RealTimeConversation) -> [String] {
        guard let lastMessage = conversation.lastMessage else {
            return ["Hey! 👋", "How's your day going?", "Nice to meet you!"]
        }
        
        return getContextualResponses(for: lastMessage, conversation: conversation)
    }
}

// MARK: - Chat Persistence Manager

class ChatPersistenceManager {
    private let conversationsKey = "realtime_conversations_v3"
    private let userDefaults = UserDefaults.standard
    private let documentsDirectory: URL
    
    init() {
        documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    func saveConversations(_ conversations: [RealTimeConversation]) {
        do {
            // Save to both UserDefaults (for quick access) and Documents (for backup)
            let data = try JSONEncoder().encode(conversations)
            
            // UserDefaults for quick access
            userDefaults.set(data, forKey: conversationsKey)
            
            // File system for persistence
            let fileURL = documentsDirectory.appendingPathComponent("conversations.json")
            try data.write(to: fileURL)
            
            print("💾 Conversations saved: \(conversations.count) items")
        } catch {
            print("❌ Failed to save conversations: \(error)")
        }
    }
    
    func loadConversations() -> [RealTimeConversation] {
        // Try loading from file first, then fallback to UserDefaults
        let fileURL = documentsDirectory.appendingPathComponent("conversations.json")
        
        if let fileData = try? Data(contentsOf: fileURL),
           let conversations = try? JSONDecoder().decode([RealTimeConversation].self, from: fileData) {
            print("📂 Loaded \(conversations.count) conversations from file")
            return conversations
        }
        
        // Fallback to UserDefaults
        guard let data = userDefaults.data(forKey: conversationsKey) else {
            print("📂 No saved conversations found")
            return []
        }
        
        do {
            let conversations = try JSONDecoder().decode([RealTimeConversation].self, from: data)
            print("📂 Loaded \(conversations.count) conversations from UserDefaults")
            return conversations
        } catch {
            print("❌ Failed to load conversations: \(error)")
            return []
        }
    }
    
    func clearAllConversations() {
        userDefaults.removeObject(forKey: conversationsKey)
        
        let fileURL = documentsDirectory.appendingPathComponent("conversations.json")
        try? FileManager.default.removeItem(at: fileURL)
        
        print("🗑️ All conversations cleared")
    }
    
    func exportConversations() -> URL? {
        let fileURL = documentsDirectory.appendingPathComponent("conversations_backup_\(Date().timeIntervalSince1970).json")
        
        if let data = userDefaults.data(forKey: conversationsKey) {
            try? data.write(to: fileURL)
            return fileURL
        }
        
        return nil
    }
}