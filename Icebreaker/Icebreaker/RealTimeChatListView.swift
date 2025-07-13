//
//  RealTimeChatListView.swift
//  Icebreaker
//
//  Created by Simon Doku on 6/25/25.
//

import SwiftUI

struct RealTimeChatListView: View {
    @StateObject private var chatManager = RealTimeChatManager.shared
    @State private var searchText = ""
    @State private var showingNewChatSheet = false
    
    private var filteredConversations: [RealTimeConversation] {
        let conversations = chatManager.activeConversations
        
        if searchText.isEmpty {
            return conversations
        } else {
            return conversations.filter { conversation in
                conversation.otherParticipantName(currentUserId: "current_user")
                    .localizedCaseInsensitiveContains(searchText) ||
                conversation.lastMessage?.text
                    .localizedCaseInsensitiveContains(searchText) == true
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                ChatListHeaderView(
                    unreadCount: chatManager.totalUnreadCount,
                    connectionStatus: chatManager.connectionStatus
                )
                
                // Search Bar
                SearchBar(text: $searchText)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                
                // Conversations List
                if filteredConversations.isEmpty {
                    EmptyChatListView(hasSearchFilter: !searchText.isEmpty)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(filteredConversations) { conversation in
                                NavigationLink(
                                    destination: RealTimeChatView(conversation: conversation)
                                ) {
                                    ChatListRowView(
                                        conversation: conversation,
                                        currentUserId: "current_user"
                                    )
                                }
                                .buttonStyle(PlainButtonStyle())
                                
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                    .padding(.leading, 80)
                            }
                        }
                    }
                }
                
                Spacer()
            }
            .background(Color(red: 0.06, green: 0.06, blue: 0.14))
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingNewChatSheet) {
            NewChatView()
        }
    }
}

struct ChatListHeaderView: View {
    let unreadCount: Int
    let connectionStatus: RealTimeChatConnectionStatus
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Messages")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    if unreadCount > 0 {
                        Text("\(unreadCount) unread")
                            .font(.subheadline)
                            .foregroundColor(.cyan)
                    }
                    
                    ConnectionStatusDot(status: connectionStatus)
                }
            }
            
            Spacer()
            
            // Settings button
            Button(action: {}) {
                Image(systemName: "gear")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

struct SearchBar: View {
    @Binding var text: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.6))
            
            TextField("Search conversations...", text: $text)
                .font(.body)
                .foregroundColor(.white)
                .focused($isFocused)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isFocused ? Color.cyan.opacity(0.5) : Color.clear, lineWidth: 1)
                )
        )
    }
}

struct ChatListRowView: View {
    let conversation: RealTimeConversation
    let currentUserId: String
    
    private var otherParticipantName: String {
        conversation.otherParticipantName(currentUserId: currentUserId)
    }
    
    private var unreadCount: Int {
        conversation.unreadCount(for: currentUserId)
    }
    
    private var isOtherUserTyping: Bool {
        conversation.isOtherUserTyping(currentUserId: currentUserId)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Avatar
            UserAvatarView(
                name: otherParticipantName,
                size: 60,
                showOnlineStatus: true
            )
            
            // Message Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(otherParticipantName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text(formatTime(conversation.lastActivity))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                HStack {
                    Group {
                        if isOtherUserTyping {
                            Text("is typing...")
                                .italic()
                                .foregroundColor(.cyan)
                        } else if let lastMessage = conversation.lastMessage {
                            HStack(spacing: 4) {
                                if lastMessage.senderId == currentUserId {
                                    DeliveryStatusIcon(status: lastMessage.deliveryStatus)
                                }
                                
                                Text(lastMessage.text)
                                    .lineLimit(2)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        } else {
                            Text("No messages yet")
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                    .font(.subheadline)
                    
                    Spacer()
                    
                    if unreadCount > 0 {
                        UnreadBadgeView(count: unreadCount)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
        )
    }
    
    private func formatTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDate(date, inSameDayAs: now) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: now) ?? now) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}

struct UserAvatarView: View {
    let name: String
    let size: CGFloat
    let showOnlineStatus: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.purple, .blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundColor(.white)
            
            if showOnlineStatus {
                Circle()
                    .fill(Color.green)
                    .frame(width: size * 0.25, height: size * 0.25)
                    .overlay(
                        Circle()
                            .stroke(Color(red: 0.06, green: 0.06, blue: 0.14), lineWidth: 2)
                    )
                    .offset(x: size * 0.3, y: size * 0.3)
            }
        }
    }
}

struct UnreadBadgeView: View {
    let count: Int
    
    var body: some View {
        Text("\(min(count, 99))")
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, count > 9 ? 8 : 6)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.red)
            )
            .overlay(
                Capsule()
                    .stroke(Color(red: 0.06, green: 0.06, blue: 0.14), lineWidth: 1)
            )
    }
}

struct EmptyChatListView: View {
    let hasSearchFilter: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: hasSearchFilter ? "magnifyingglass" : "message")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))
            
            VStack(spacing: 8) {
                Text(hasSearchFilter ? "No conversations found" : "No conversations yet")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white.opacity(0.8))
                
                Text(hasSearchFilter ? 
                     "Try searching with different keywords" : 
                     "Start connecting with people to begin chatting!")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
            
            if !hasSearchFilter {
                Button("Find Matches") {
                    // Navigate to radar/matches view
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.cyan)
                )
            }
        }
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct NewChatView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Start New Chat")
                    .font(.title)
                    .foregroundColor(.white)
                
                Text("Feature coming soon...")
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
            }
            .padding()
            .background(Color(red: 0.06, green: 0.06, blue: 0.14))
            .navigationTitle("New Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.cyan)
                }
            }
        }
    }
}

#Preview {
    RealTimeChatListView()
}