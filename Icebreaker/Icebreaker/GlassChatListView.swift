//
//  ChatListView.swift
//  Icebreaker
//
//  Created by Simon Doku on 6/23/25.
//

import SwiftUI

struct GlassChatListView: View {
    @EnvironmentObject var chatManager: IcebreakerChatManager
    @EnvironmentObject var authManager: FirebaseAuthManager
    @State private var selectedConversation: IcebreakerChatConversation?
    @State private var showingChatView = false
    @State private var searchText = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                if chatManager.conversations.isEmpty {
                    EmptyChatView()
                } else {
                    List {
                        ForEach(chatManager.conversations) { conversation in
                            IcebreakerChatRow(conversation: conversation) {
                                selectedConversation = conversation
                                showingChatView = true
                                chatManager.markAsRead(conversation.id)
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(PlainListStyle())
                }            }
            .navigationTitle("Messages")
            .sheet(isPresented: $showingChatView) {
                if let conversation = selectedConversation {
                    SimpleIcebreakerChatView(conversation: conversation)
                }
            }
            .onAppear {
                // Force refresh to show any new conversations
                chatManager.objectWillChange.send()
            }
        }
    }
    
    // Individual chat row using the Icebreaker types
    struct IcebreakerChatRow: View {
        let conversation: IcebreakerChatConversation
        let onTap: () -> Void
        
        var body: some View {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // Avatar
                    Circle()
                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(conversation.otherUserName.prefix(1))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                        )
                    
                    // Message info
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(conversation.otherUserName)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text(conversation.lastMessageTime, style: .time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text(conversation.lastMessage)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                            
                            Spacer()
                            
                            if conversation.unreadCount > 0 {
                                Text("\(conversation.unreadCount)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // Simple chat view for the Icebreaker conversations
    struct SimpleIcebreakerChatView: View {
        let conversation: IcebreakerChatConversation
        @Environment(\.dismiss) private var dismiss
        @EnvironmentObject var chatManager: IcebreakerChatManager
        @State private var messageText = ""
        @State private var messages: [IcebreakerMessage] = []
        @State private var aiSuggestions: [String] = []
        @State private var showingSuggestions = true
        
        var body: some View {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button("Back") { dismiss() }
                        .foregroundColor(.cyan)
                    Spacer()
                    Text(conversation.otherUserName)
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Button("Info") { }
                        .foregroundColor(.cyan)
                }
                .padding()
                .background(Color.black.opacity(0.3))
                
                // Messages area
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                MessageBubbleView(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) {
                        if let lastMessage = messages.last {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
                
                // AI Suggestions Section
                if showingSuggestions && !aiSuggestions.isEmpty {
                    ChatAISuggestionsSection(
                        suggestions: aiSuggestions,
                        onSuggestionTap: { suggestion in
                            messageText = suggestion
                            showingSuggestions = false
                        }
                    )
                    .padding(.horizontal, 16)
                }
                
                // Input
                HStack(spacing: 12) {
                    TextField("Type a message...", text: $messageText)
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                        .onSubmit {
                            sendMessage()
                        }
                        .onChange(of: messageText) { _, newValue in
                            if newValue.isEmpty && !showingSuggestions {
                                showingSuggestions = true
                                generateAISuggestions()
                            }
                        }
                    
                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(canSend ? Color.cyan : Color.gray)
                            )
                    }
                    .disabled(!canSend)
                    .animation(.easeInOut(duration: 0.2), value: canSend)
                }
                .padding()
                .background(Color.black.opacity(0.2))
            }
            .background(Color(red: 0.06, green: 0.06, blue: 0.14))
            .onAppear {
                loadMessages()
                generateAISuggestions()
            }
        }
        
        private var canSend: Bool {
            !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        
        private func sendMessage() {
            let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            
            let newMessage = IcebreakerMessage(
                id: UUID().uuidString,
                senderId: "current_user",
                senderName: "You",
                text: text,
                timestamp: Date(),
                isFromCurrentUser: true
            )
            
            messages.append(newMessage)
            messageText = ""
            
            // Update the conversation in the chat manager
            chatManager.updateConversation(IcebreakerChatConversation(
                id: conversation.id,
                matchId: conversation.matchId,
                otherUserName: conversation.otherUserName,
                lastMessage: text,
                lastMessageTime: Date(),
                unreadCount: conversation.unreadCount
            ))
            
            // Simulate response after delay
            simulateResponse()
        }
        
        private func loadMessages() {
            // Load existing messages for this conversation
            messages = [
                IcebreakerMessage(
                    id: UUID().uuidString,
                    senderId: "other_user",
                    senderName: conversation.otherUserName,
                    text: conversation.lastMessage,
                    timestamp: conversation.lastMessageTime,
                    isFromCurrentUser: false
                )
            ]
        }
        
        private func simulateResponse() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                let responses = [
                    "That's really interesting! Tell me more.",
                    "I completely agree with that perspective.",
                    "Wow, we have so much in common!",
                    "That sounds amazing. I'd love to try that sometime.",
                    "You seem like someone I'd really enjoy talking to!",
                    "I'm so glad we connected through this app."
                ]
                
                let response = IcebreakerMessage(
                    id: UUID().uuidString,
                    senderId: "other_user",
                    senderName: conversation.otherUserName,
                    text: responses.randomElement() ?? "Thanks for sharing!",
                    timestamp: Date(),
                    isFromCurrentUser: false
                )
                
                messages.append(response)
                
                // Update conversation in chat manager with new response
                chatManager.updateConversation(IcebreakerChatConversation(
                    id: conversation.id,
                    matchId: conversation.matchId,
                    otherUserName: conversation.otherUserName,
                    lastMessage: response.text,
                    lastMessageTime: response.timestamp,
                    unreadCount: conversation.unreadCount
                ))
            }
        }
        
        private func generateAISuggestions() {
            // Generate AI suggestions based on conversation context
            let lastMessage = messages.last?.text ?? ""
            
            if lastMessage.lowercased().contains("book") || lastMessage.lowercased().contains("reading") {
                aiSuggestions = [
                    "What's your favorite genre?",
                    "Any book recommendations for me?",
                    "I love getting lost in a good story too! 📚"
                ]
            } else if lastMessage.lowercased().contains("coffee") || lastMessage.lowercased().contains("cafe") {
                aiSuggestions = [
                    "What's your go-to coffee order?",
                    "Know any good cafes around here?",
                    "Coffee enthusiast here too! ☕"
                ]
            } else if lastMessage.lowercased().contains("work") || lastMessage.lowercased().contains("job") {
                aiSuggestions = [
                    "What do you do for work?",
                    "How do you like your job?",
                    "Work-life balance is so important!"
                ]
            } else if lastMessage.lowercased().contains("travel") || lastMessage.lowercased().contains("trip") {
                aiSuggestions = [
                    "Where's your dream destination?",
                    "I love exploring new places too!",
                    "What was your best travel experience?"
                ]
            } else if messages.count <= 2 {
                // Opening conversation suggestions
                aiSuggestions = [
                    "Want to be accountability partners? 🤝",
                    "What chapter are you on?",
                    "Coffee meetup to discuss the book? ☕"
                ]
            } else {
                // General conversation continuers
                aiSuggestions = [
                    "That's really interesting!",
                    "Tell me more about that",
                    "I'd love to hear your thoughts on that"
                ]
            }
        }
    }
    
    // Message model for the simple chat
    struct IcebreakerMessage: Identifiable {
        let id: String
        let senderId: String
        let senderName: String
        let text: String
        let timestamp: Date
        let isFromCurrentUser: Bool
    }
    
    // Message bubble view
    struct MessageBubbleView: View {
        let message: IcebreakerMessage
        
        var body: some View {
            HStack {
                if message.isFromCurrentUser {
                    Spacer(minLength: 60)
                }
                
                VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                    Text(message.text)
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(message.isFromCurrentUser ? Color.cyan : Color.white.opacity(0.15))
                        )
                    
                    Text(formatTime(message.timestamp))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 8)
                }
                
                if !message.isFromCurrentUser {
                    Spacer(minLength: 60)
                }
            }
        }
        
        private func formatTime(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
    
    // Empty chat state
    struct EmptyChatView: View {
        var body: some View {
            VStack(spacing: 20) {
                Spacer()
                
                Text("💬")
                    .font(.system(size: 80))
                
                Text("No conversations yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                VStack(spacing: 8) {
                    Text("Start connecting with people nearby!")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    Text("Check out the Radar and Matches tabs.")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal)
                
                Spacer()
            }
        }
    }
    
    // AI Suggestions Section for Chat
    struct ChatAISuggestionsSection: View {
        let suggestions: [String]
        let onSuggestionTap: (String) -> Void
        
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("💡 AI suggests:")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Spacer()
                }
                
                VStack(spacing: 8) {
                    ForEach(suggestions.prefix(3), id: \.self) { suggestion in
                        Button(action: { onSuggestionTap(suggestion) }) {
                            Text(suggestion)
                                .font(.body)
                                .foregroundColor(.white.opacity(0.8))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 24)
                                        .fill(Color.white.opacity(0.08))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 24)
                                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
    }
}

#Preview {
    GlassChatListView()
}
