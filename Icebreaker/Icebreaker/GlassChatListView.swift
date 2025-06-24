//
//  ChatListView.swift
//  Icebreaker
//
//  Created by Simon Doku on 6/23/25.
//

import SwiftUI

struct GlassChatListView: View {
    @StateObject private var chatManager = ChatManager()
    @State private var selectedConversation: Conversation?
    @State private var showingChat = false
    
    var body: some View {
        NavigationStack {
                if chatManager.conversations.isEmpty {
                    EmptyChatView()
                } else {
                    List {
                        ForEach(chatManager.conversations) { conversation in
                            ChatRow(conversation: conversation) {
                                selectedConversation = conversation
                                showingChat = true
                                chatManager.markAsRead(conversationId: conversation.id)
                            }
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                        }
                    }
                    .listStyle(PlainListStyle())
                }            }
            .navigationTitle("Messages")
            .sheet(isPresented: $showingChat) {
                if let conversation = selectedConversation {
                    ChatView(conversation: conversation, chatManager: chatManager)
                }
            }
        }
    }

// Individual chat row
struct ChatRow: View {
    let conversation: Conversation
    let onTap: () -> Void
    
    private var otherParticipantName: String {
        conversation.otherParticipantName(currentUserId: "current_user")
    }
    
    private var unreadCount: Int {
        conversation.unreadCount(for: "current_user")
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(otherParticipantName.prefix(1))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    )
                
                // Message info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(otherParticipantName)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(conversation.lastMessageTimestamp, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        if let lastMessage = conversation.lastMessage {
                            Text(lastMessage.text)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                        
                        Spacer()
                        
                        if unreadCount > 0 {
                            Text("\(unreadCount)")
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

#Preview {
    GlassChatListView()
}
