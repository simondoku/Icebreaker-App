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

// MARK: - Real-Time Chat Manager

class RealTimeChatManager: ObservableObject {
    static let shared = RealTimeChatManager()
    
    // Published properties for UI updates
    @Published var conversations: [RealTimeConversation] = []
    @Published var activeConversation: RealTimeConversation?
    @Published var connectionStatus: RealTimeChatConnectionStatus = .disconnected
    @Published var isTyping: Bool = false
    
    // Private properties
    private let currentUserId: String
    private let persistenceManager = ChatPersistenceManager()
    private var cancellables = Set<AnyCancellable>()
    private var typingTimer: Timer?
    
    // Auto-save and connection management timers
    private var autoSaveTimer: Timer?
    private var reconnectionTimer: Timer?
    private var messageProcessingTimer: Timer?
    private var connectionSimulationTimer: Timer?
    
    // Real-time simulation
    private var messageQueue: [RealTimeMessage] = []
    private var isProcessingQueue = false
    
    // CRITICAL FIX: Add thread-safe access to conversations array
    private let conversationsQueue = DispatchQueue(label: "com.icebreaker.conversations", attributes: .concurrent)
    
    init(currentUserId: String = "current_user") {
        self.currentUserId = currentUserId
        setupRealTimeChat()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Setup & Initialization
    
    private func setupRealTimeChat() {
        loadConversations()
        startConnectionSimulation()
        setupAutoSave()
        setupMessageProcessing()
    }
    
    private func cleanup() {
        // CRITICAL FIX: Properly invalidate all timers to prevent memory leaks
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
        
        reconnectionTimer?.invalidate()
        reconnectionTimer = nil
        
        messageProcessingTimer?.invalidate()
        messageProcessingTimer = nil
        
        connectionSimulationTimer?.invalidate()
        connectionSimulationTimer = nil
        
        typingTimer?.invalidate()
        typingTimer = nil
        
        cancellables.removeAll()
        
        // Clear message queue to prevent processing after cleanup
        messageQueue.removeAll()
        isProcessingQueue = false
    }
    
    private func setupMessageProcessing() {
        // CRITICAL FIX: Use weak self to prevent retain cycles and properly invalidate existing timer
        messageProcessingTimer?.invalidate()
        messageProcessingTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            self.processMessageQueue()
        }
    }
    
    // MARK: - Thread-Safe Access Methods
    
    private func safeReadConversations<T>(_ operation: ([RealTimeConversation]) -> T) -> T {
        return conversationsQueue.sync {
            return operation(conversations)
        }
    }
    
    private func safeWriteConversations(_ operation: @escaping (inout [RealTimeConversation]) -> Void) {
        conversationsQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            operation(&self.conversations)
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    
    // MARK: - Public Methods
    
    func sendMessage(_ text: String, to conversationId: String, type: MessageType = .text) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let message = RealTimeMessage(
            senderId: currentUserId,
            text: text
        )
        
        safeWriteConversations { conversations in
            guard let conversationIndex = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
            conversations[conversationIndex].messages.append(message)
            conversations[conversationIndex].lastActivity = message.timestamp
        }
        
        simulateMessageDelivery(messageId: message.id, conversationId: conversationId)
        
        // Stop typing indicator
        setTypingStatus(false, in: conversationId)
        
        // Simulate reply from other user (for demo)
        simulateReply(to: conversationId, after: 2.0)
        
        DispatchQueue.main.async { [weak self] in
            self?.saveConversations()
        }
    }
    
    func markMessagesAsRead(in conversationId: String) {
        safeWriteConversations { conversations in
            guard let conversationIndex = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
            
            for messageIndex in conversations[conversationIndex].messages.indices {
                if conversations[conversationIndex].messages[messageIndex].senderId != self.currentUserId {
                    conversations[conversationIndex].messages[messageIndex].isRead = true
                    conversations[conversationIndex].messages[messageIndex].deliveryStatus = .read
                }
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.updateActiveConversation(conversationId)
            self?.saveConversations()
        }
    }
    
    func setTypingStatus(_ isTyping: Bool, in conversationId: String) {
        safeWriteConversations { conversations in
            guard let conversationIndex = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
            
            if isTyping {
                if !conversations[conversationIndex].typingUsers.contains(self.currentUserId) {
                    conversations[conversationIndex].typingUsers.append(self.currentUserId)
                }
            } else {
                conversations[conversationIndex].typingUsers.removeAll { $0 == self.currentUserId }
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.updateActiveConversation(conversationId)
            
            if isTyping {
                // Reset typing timer with proper cleanup
                self.typingTimer?.invalidate()
                self.typingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                    self?.setTypingStatus(false, in: conversationId)
                }
            } else {
                self.typingTimer?.invalidate()
                self.typingTimer = nil
            }
        }
    }
    
    func createConversation(with userId: String, userName: String) -> RealTimeConversation {
        let conversation = RealTimeConversation(
            participantIds: [currentUserId, userId],
            participantNames: ["You", userName]
        )
        
        safeWriteConversations { conversations in
            conversations.append(conversation)
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.saveConversations()
        }
        
        return conversation
    }
    
    func deleteConversation(_ conversationId: String) {
        safeWriteConversations { conversations in
            conversations.removeAll { $0.id == conversationId }
        }
        
        DispatchQueue.main.async { [weak self] in
            if self?.activeConversation?.id == conversationId {
                self?.activeConversation = nil
            }
            self?.saveConversations()
        }
    }
    
    func setActiveConversation(_ conversation: RealTimeConversation?) {
        activeConversation = conversation
        
        if let conversation = conversation {
            markMessagesAsRead(in: conversation.id)
        }
    }
    
    // MARK: - Private Helper Methods
    
    private func addMessageToConversation(_ message: RealTimeMessage, to conversationId: String) {
        safeWriteConversations { conversations in
            guard let conversationIndex = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
            conversations[conversationIndex].messages.append(message)
            conversations[conversationIndex].lastActivity = message.timestamp
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.updateActiveConversation(conversationId)
            self?.saveConversations()
        }
    }
    
    private func updateActiveConversation(_ conversationId: String) {
        let conversation = safeReadConversations { conversations in
            return conversations.first { $0.id == conversationId }
        }
        
        DispatchQueue.main.async { [weak self] in
            if self?.activeConversation?.id == conversationId {
                self?.activeConversation = conversation
            }
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
        safeWriteConversations { conversations in
            guard let conversationIndex = conversations.firstIndex(where: { $0.id == conversationId }),
                  let messageIndex = conversations[conversationIndex].messages.firstIndex(where: { $0.id == messageId }) else { return }
            
            conversations[conversationIndex].messages[messageIndex].deliveryStatus = status
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.updateActiveConversation(conversationId)
            self?.saveConversations()
        }
    }
    
    private func simulateReply(to conversationId: String, after delay: TimeInterval) {
        let (otherUserName, otherUserId) = safeReadConversations { conversations in
            guard let conversation = conversations.first(where: { $0.id == conversationId }) else { 
                return ("Unknown", "unknown")
            }
            let otherUserName = conversation.otherParticipantName(currentUserId: self.currentUserId)
            let otherUserId = conversation.participantIds.first { $0 != self.currentUserId } ?? "unknown"
            return (otherUserName, otherUserId)
        }
        
        // Simulate typing indicator
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            
            self.safeWriteConversations { conversations in
                guard let conversationIndex = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
                if !conversations[conversationIndex].typingUsers.contains(otherUserId) {
                    conversations[conversationIndex].typingUsers.append(otherUserId)
                }
            }
            
            DispatchQueue.main.async { [weak self] in
                self?.updateActiveConversation(conversationId)
            }
            
            // Send reply after typing
            DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 1.0...3.0)) { [weak self] in
                self?.sendSimulatedReply(conversationId: conversationId, senderId: otherUserId, senderName: otherUserName)
            }
        }
    }
    
    private func sendSimulatedReply(conversationId: String, senderId: String, senderName: String) {
        let lastMessage: RealTimeMessage? = safeReadConversations { conversations in
            guard let conversation = conversations.first(where: { $0.id == conversationId }) else { 
                return nil as RealTimeMessage?
            }
            return conversation.lastMessage
        }
        
        // Stop typing
        safeWriteConversations { conversations in
            guard let conversationIndex = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
            conversations[conversationIndex].typingUsers.removeAll { $0 == senderId }
        }
        
        let replies = getContextualResponses(for: lastMessage, conversationId: conversationId)
        let replyText = replies.randomElement() ?? "That's interesting!"
        
        // Create message with proper delivery status using the new initializer
        let replyMessage = RealTimeMessage(
            senderId: senderId,
            text: replyText,
            deliveryStatus: .delivered
        )
        
        addMessageToConversation(replyMessage, to: conversationId)
    }
    
    private func getContextualResponses(for lastMessage: RealTimeMessage?, conversationId: String) -> [String] {
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
            self?.addMessageToConversation(message, to: message.conversationId)
            self?.isProcessingQueue = false
        }
    }
    
    private func startConnectionSimulation() {
        connectionStatus = .connecting
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.connectionStatus = .connected
        }
        
        // Simulate occasional disconnections with weak self
        connectionSimulationTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            if Bool.random() && self?.connectionStatus == .connected {
                self?.connectionStatus = .reconnecting
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
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
        var sampleConversation = RealTimeConversation(
            participantIds: [currentUserId, "alex_demo_123"],
            participantNames: ["You", "Alex"]
        )
        
        // Add sample messages
        let messages = [
            RealTimeMessage(
                senderId: "alex_demo_123",
                text: "Hey! I saw you're also into reading. What's the last book that completely changed your perspective? 📚"
            ),
            RealTimeMessage(
                senderId: currentUserId,
                text: "Hi Alex! I just finished 'Atomic Habits' and it's been a game-changer for my daily routine. The 1% better concept is so powerful! What about you?"
            ),
            RealTimeMessage(
                senderId: "alex_demo_123",
                text: "That's amazing! I love that book too. I've been working on the 'habit stacking' technique for my morning routine. Have you tried implementing any specific habits from it?"
            )
        ]
        
        sampleConversation.messages = messages
        sampleConversation.lastActivity = messages.last?.timestamp ?? Date()
        
        // Set delivery status for demo messages
        for i in sampleConversation.messages.indices {
            sampleConversation.messages[i].deliveryStatus = .read
            sampleConversation.messages[i].isRead = true
        }
        
        conversations.append(sampleConversation)
        saveConversations()
    }
    
    // MARK: - Public Getters
    
    var totalUnreadCount: Int {
        return conversations.reduce(0) { total, conversation in
            total + conversation.unreadCount(for: currentUserId)
        }
    }
    
    var activeConversations: [RealTimeConversation] {
        return conversations.sorted { $0.lastActivity > $1.lastActivity }
    }
    
    func getConversation(by id: String) -> RealTimeConversation? {
        return conversations.first { $0.id == id }
    }
    
    func getMessageSuggestions(for conversation: RealTimeConversation) -> [String] {
        guard let lastMessage = conversation.lastMessage else {
            return ["Hey! 👋", "How's your day going?", "Nice to meet you!"]
        }
        
        return getContextualResponses(for: lastMessage, conversationId: conversation.id)
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