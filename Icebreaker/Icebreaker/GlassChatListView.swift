//
//  ChatListView.swift
//  Icebreaker
//
//  Created by Simon Doku on 6/23/25.
//

import SwiftUI

struct GlassChatListView: View {
    @EnvironmentObject var chatManager: IcebreakerChatManager
    @State private var selectedConversation: IcebreakerChatConversation?
    @State private var showingChat = false
    
    var body: some View {
        NavigationStack {
                if chatManager.conversations.isEmpty {
                    EmptyChatView()
                } else {
                    List {
                        ForEach(chatManager.conversations) { conversation in
                            IcebreakerChatRow(conversation: conversation) {
                                selectedConversation = conversation
                                showingChat = true
                                chatManager.markAsRead(conversation.id)
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
                    SimpleIcebreakerChatView(conversation: conversation)
                }
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
    @State private var messageText = ""
    
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
            ScrollView {
                VStack(spacing: 12) {
                    Text(conversation.lastMessage)
                        .font(.body)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                }
                .padding()
            }
            
            // Input
            HStack {
                TextField("Type a message...", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("Send") {
                    messageText = ""
                }
                .disabled(messageText.isEmpty)
            }
            .padding()
        }
        .background(AnimatedBackground().ignoresSafeArea())
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
