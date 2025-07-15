//
//  RealTimeChatManager.swift
//  Icebreaker
//
//  Created by Simon Doku on 6/25/25.
//

import Foundation
import Combine
import SwiftUI
import Firebase
import FirebaseFirestore
import FirebaseAuth

// MARK: - Firebase Real-Time Chat Manager

class RealTimeChatManager: ObservableObject {
    static let shared = RealTimeChatManager()
    
    // Published properties for UI updates
    @Published var conversations: [RealTimeConversation] = []
    @Published var activeConversation: RealTimeConversation?
    @Published var connectionStatus: RealTimeChatConnectionStatus = .disconnected
    @Published var isTyping: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // Firebase properties
    private let db = Firestore.firestore()
    private var conversationsListener: ListenerRegistration?
    private var activeConversationListener: ListenerRegistration?
    private var typingTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // Current user
    var currentUserId: String {
        return Auth.auth().currentUser?.uid ?? "anonymous"
    }
    
    init() {
        setupAuthStateListener()
    }
    
    deinit {
        cleanup()
    }
    
    // MARK: - Setup & Authentication
    
    private func setupAuthStateListener() {
        Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            if let user = user {
                self?.setupRealTimeChat(for: user.uid)
            } else {
                self?.cleanup()
            }
        }
    }
    
    private func setupRealTimeChat(for userId: String) {
        connectionStatus = .connecting
        setupConversationsListener()
        connectionStatus = .connected
    }
    
    private func cleanup() {
        conversationsListener?.remove()
        activeConversationListener?.remove()
        typingTimer?.invalidate()
        cancellables.removeAll()
        
        conversations.removeAll()
        activeConversation = nil
        connectionStatus = .disconnected
    }
    
    // MARK: - Firestore Listeners
    
    private func setupConversationsListener() {
        guard !currentUserId.isEmpty else { return }
        
        conversationsListener?.remove()
        
        conversationsListener = db.collection("conversations")
            .whereField("participantIds", arrayContains: currentUserId)
            .order(by: "lastActivity", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Conversations listener error: \(error)")
                    self?.errorMessage = "Failed to load conversations"
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                Task { @MainActor in
                    self?.updateConversationsFromSnapshot(documents)
                }
            }
    }
    
    @MainActor
    private func updateConversationsFromSnapshot(_ documents: [QueryDocumentSnapshot]) {
        var updatedConversations: [RealTimeConversation] = []
        
        for document in documents {
            do {
                let data = document.data()
                let conversation = try parseConversationFromFirestore(id: document.documentID, data: data)
                updatedConversations.append(conversation)
            } catch {
                print("❌ Error parsing conversation: \(error)")
            }
        }
        
        self.conversations = updatedConversations
        print("✅ Updated \(updatedConversations.count) conversations from Firestore")
    }
    
    private func parseConversationFromFirestore(id: String, data: [String: Any]) throws -> RealTimeConversation {
        guard let participantIds = data["participantIds"] as? [String],
              let participantNames = data["participantNames"] as? [String] else {
            throw NSError(domain: "ChatError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid conversation data"])
        }
        
        var conversation = RealTimeConversation(participantIds: participantIds, participantNames: participantNames)
        conversation.id = id
        conversation.lastActivity = (data["lastActivity"] as? Timestamp)?.dateValue() ?? Date()
        conversation.typingUsers = data["typingUsers"] as? [String] ?? []
        
        // Parse unread counts
        if let unreadData = data["unreadCounts"] as? [String: Int] {
            conversation.unreadCounts = unreadData
        }
        
        return conversation
    }
    
    private func setupActiveConversationListener(for conversationId: String) {
        activeConversationListener?.remove()
        
        activeConversationListener = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Messages listener error: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                Task { @MainActor in
                    self?.updateActiveConversationMessages(documents, conversationId: conversationId)
                }
            }
    }
    
    @MainActor
    private func updateActiveConversationMessages(_ documents: [QueryDocumentSnapshot], conversationId: String) {
        guard var conversation = activeConversation, conversation.id == conversationId else { return }
        
        var messages: [RealTimeMessage] = []
        
        for document in documents {
            do {
                let data = document.data()
                let message = try parseMessageFromFirestore(id: document.documentID, data: data)
                messages.append(message)
            } catch {
                print("❌ Error parsing message: \(error)")
            }
        }
        
        conversation.messages = messages
        activeConversation = conversation
        
        // Mark messages as read when viewing
        markMessagesAsRead(in: conversationId)
    }
    
    private func parseMessageFromFirestore(id: String, data: [String: Any]) throws -> RealTimeMessage {
        guard let senderId = data["senderId"] as? String,
              let text = data["text"] as? String,
              let timestamp = (data["timestamp"] as? Timestamp)?.dateValue() else {
            throw NSError(domain: "ChatError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid message data"])
        }
        
        let deliveryStatusString = data["deliveryStatus"] as? String ?? "sent"
        let deliveryStatus = MessageDeliveryStatus(rawValue: deliveryStatusString) ?? .sent
        let isRead = data["isRead"] as? Bool ?? false
        
        return RealTimeMessage(
            id: id,
            senderId: senderId,
            text: text,
            timestamp: timestamp,
            deliveryStatus: deliveryStatus
        )
    }
    
    // MARK: - Public Chat Methods
    
    func sendMessage(_ text: String, to conversationId: String) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard !currentUserId.isEmpty else { return }
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            let messageData: [String: Any] = [
                "senderId": currentUserId,
                "text": text,
                "timestamp": Timestamp(),
                "deliveryStatus": MessageDeliveryStatus.sent.rawValue,
                "isRead": false
            ]
            
            // Add message to subcollection
            let messageRef = try await db.collection("conversations")
                .document(conversationId)
                .collection("messages")
                .addDocument(data: messageData)
            
            // Get the other participant ID safely
            let otherParticipantId = getOtherParticipantId(conversationId: conversationId)
            
            // Update conversation metadata
            var updateData: [String: Any] = [
                "lastActivity": Timestamp(),
                "lastMessage": text,
                "lastMessageSenderId": currentUserId
            ]
            
            // Only update unread count if we have a valid other participant ID
            if !otherParticipantId.isEmpty {
                updateData["unreadCounts.\(otherParticipantId)"] = FieldValue.increment(Int64(1))
            }
            
            try await db.collection("conversations")
                .document(conversationId)
                .updateData(updateData)
            
            await MainActor.run {
                isLoading = false
                // Stop typing indicator
                setTypingStatus(false, in: conversationId)
            }
            
            print("✅ Message sent successfully")
            
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Failed to send message: \(error.localizedDescription)"
            }
            print("❌ Error sending message: \(error)")
        }
    }
    
    func createConversation(with userId: String, userName: String) async -> RealTimeConversation? {
        guard !currentUserId.isEmpty else { return nil }
        
        await MainActor.run {
            isLoading = true
        }
        
        do {
            // Check if conversation already exists
            let existingConversation = conversations.first { conversation in
                conversation.participantIds.contains(userId) && conversation.participantIds.contains(currentUserId)
            }
            
            if let existing = existingConversation {
                await MainActor.run {
                    isLoading = false
                }
                return existing
            }
            
            // Get current user's name
            let currentUserName = await getCurrentUserName()
            
            // Create new conversation
            let conversationData: [String: Any] = [
                "participantIds": [currentUserId, userId],
                "participantNames": [currentUserName, userName],
                "lastActivity": Timestamp(),
                "lastMessage": "",
                "lastMessageSenderId": "",
                "typingUsers": [],
                "unreadCounts": [
                    currentUserId: 0,
                    userId: 0
                ]
            ]
            
            let conversationRef = try await db.collection("conversations").addDocument(data: conversationData)
            
            var newConversation = RealTimeConversation(
                participantIds: [currentUserId, userId],
                participantNames: [currentUserName, userName]
            )
            
            // Set the correct conversation ID
            newConversation.id = conversationRef.documentID
            
            await MainActor.run {
                isLoading = false
            }
            
            print("✅ Conversation created successfully with ID: \(conversationRef.documentID)")
            return newConversation
            
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Failed to create conversation: \(error.localizedDescription)"
            }
            print("❌ Error creating conversation: \(error)")
            return nil
        }
    }
    
    // Helper method to get current user's name
    private func getCurrentUserName() async -> String {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return "You" }
        
        do {
            let userDoc = try await db.collection("users").document(currentUserId).getDocument()
            if let userData = userDoc.data(),
               let firstName = userData["firstName"] as? String {
                return firstName
            }
        } catch {
            print("❌ Error getting current user name: \(error)")
        }
        
        return "You"
    }
    
    func setActiveConversation(_ conversation: RealTimeConversation?) {
        // Clean up previous listener
        activeConversationListener?.remove()
        
        activeConversation = conversation
        
        if let conversation = conversation {
            setupActiveConversationListener(for: conversation.id)
            markMessagesAsRead(in: conversation.id)
        }
    }
    
    func markMessagesAsRead(in conversationId: String) {
        guard !currentUserId.isEmpty else { return }
        
        Task {
            do {
                // Reset unread count for current user
                try await db.collection("conversations")
                    .document(conversationId)
                    .updateData([
                        "unreadCounts.\(currentUserId)": 0
                    ])
                
                // Update read status for unread messages from other users
                let messagesSnapshot = try await db.collection("conversations")
                    .document(conversationId)
                    .collection("messages")
                    .whereField("senderId", isNotEqualTo: currentUserId)
                    .whereField("isRead", isEqualTo: false)
                    .getDocuments()
                
                let batch = db.batch()
                for document in messagesSnapshot.documents {
                    batch.updateData([
                        "isRead": true,
                        "deliveryStatus": MessageDeliveryStatus.read.rawValue
                    ], forDocument: document.reference)
                }
                
                try await batch.commit()
                
            } catch {
                print("❌ Error marking messages as read: \(error)")
            }
        }
    }
    
    func setTypingStatus(_ isTyping: Bool, in conversationId: String) {
        guard !currentUserId.isEmpty else { return }
        
        Task {
            do {
                if isTyping {
                    try await db.collection("conversations")
                        .document(conversationId)
                        .updateData([
                            "typingUsers": FieldValue.arrayUnion([currentUserId])
                        ])
                    
                    // Reset typing timer
                    await MainActor.run {
                        self.typingTimer?.invalidate()
                        self.typingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                            self?.setTypingStatus(false, in: conversationId)
                        }
                    }
                } else {
                    try await db.collection("conversations")
                        .document(conversationId)
                        .updateData([
                            "typingUsers": FieldValue.arrayRemove([currentUserId])
                        ])
                    
                    await MainActor.run {
                        self.typingTimer?.invalidate()
                        self.typingTimer = nil
                    }
                }
            } catch {
                print("❌ Error updating typing status: \(error)")
            }
        }
    }
    
    func deleteConversation(_ conversationId: String) async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            // Delete all messages in the conversation
            let messagesSnapshot = try await db.collection("conversations")
                .document(conversationId)
                .collection("messages")
                .getDocuments()
            
            let batch = db.batch()
            for document in messagesSnapshot.documents {
                batch.deleteDocument(document.reference)
            }
            
            // Delete the conversation document
            batch.deleteDocument(db.collection("conversations").document(conversationId))
            
            try await batch.commit()
            
            await MainActor.run {
                isLoading = false
                if activeConversation?.id == conversationId {
                    activeConversation = nil
                    activeConversationListener?.remove()
                }
            }
            
            print("✅ Conversation deleted successfully")
            
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Failed to delete conversation: \(error.localizedDescription)"
            }
            print("❌ Error deleting conversation: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func getOtherParticipantId(conversationId: String) -> String {
        guard let conversation = conversations.first(where: { $0.id == conversationId }) else {
            return ""
        }
        return conversation.participantIds.first { $0 != currentUserId } ?? ""
    }
    
    // MARK: - Public Getters
    
    var totalUnreadCount: Int {
        return conversations.reduce(0) { total, conversation in
            total + (conversation.unreadCounts[currentUserId] ?? 0)
        }
    }
    
    func getConversation(for userId: String) -> RealTimeConversation? {
        return conversations.first { conversation in
            conversation.participantIds.contains(userId) && conversation.participantIds.contains(currentUserId)
        }
    }
    
    func getConversation(by id: String) -> RealTimeConversation? {
        return conversations.first { $0.id == id }
    }
}