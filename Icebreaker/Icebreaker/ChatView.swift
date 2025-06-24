import SwiftUI

struct ChatView: View {
    let conversation: Conversation
    let chatManager: ChatManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var messageText = ""
    @State private var showingSuggestions = true
    @State private var showingAISuggestedOpening = true
    
    private var otherParticipantName: String {
        conversation.otherParticipantName(currentUserId: chatManager.currentUserId)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Header
            ChatHeaderView(
                name: "Alex",
                matchPercentage: 92,
                distance: "8m away",
                onBackTap: { dismiss() },
                onInfoTap: { /* Handle info */ }
            )
            
            // Chat Messages
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        // AI Suggested Opening (shows at start of conversation)
                        if showingAISuggestedOpening {
                            AISuggestedOpeningCard()
                                .padding(.horizontal, 16)
                                .padding(.top, 16)
                        }
                        
                        // Sample Messages to match your images
                        VStack(spacing: 12) {
                            // User's opening message
                            ChatMessageBubble(
                                text: "Hey! I saw you're also reading Atomic Habits. Which habit are you working on building right now? 📚",
                                timestamp: "2:34 PM",
                                isCurrentUser: false,
                                isFirstMessage: true
                            )
                            
                            // Alex's response
                            ChatMessageBubble(
                                text: "Perfect! I'm trying to build a consistent morning routine. The 1% better concept is brilliant! 📖",
                                timestamp: "2:35 PM",
                                isCurrentUser: true
                            )
                            
                            // User's follow-up
                            ChatMessageBubble(
                                text: "Same here! I've been doing the coffee + journaling combo for 3 weeks now. What does your morning routine look like?",
                                timestamp: "2:36 PM",
                                isCurrentUser: false
                            )
                            
                            // Alex's latest response
                            ChatMessageBubble(
                                text: "Nice! I start with coffee too, then 10 minutes of reading. Still working on making it automatic 😅",
                                timestamp: "2:37 PM",
                                isCurrentUser: true
                            )
                        }
                        .padding(.horizontal, 16)
                        
                        // AI Suggestions Section
                        if showingSuggestions {
                            AISuggestionsSection()
                                .padding(.horizontal, 16)
                                .padding(.top, 20)
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            
            // Message Input Area
            ChatInputView(messageText: $messageText) {
                sendMessage()
            }
        }
        .background(Color(red: 0.06, green: 0.06, blue: 0.14))
        .navigationBarHidden(true)
    }
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        // Handle sending message
        messageText = ""
        showingAISuggestedOpening = false
    }
}

struct ChatHeaderView: View {
    let name: String
    let matchPercentage: Int
    let distance: String
    let onBackTap: () -> Void
    let onInfoTap: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // Back button
            Button(action: onBackTap) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.cyan)
            }
            
            // Avatar
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.red, .green],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 50, height: 50)
                .overlay(
                    Text("A")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                )
            
            // Name and match info
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("\(matchPercentage)% match • \(distance)")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            // Info button
            Button(action: onInfoTap) {
                Image(systemName: "info.circle")
                    .font(.title2)
                    .foregroundColor(.cyan)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.3))
    }
}

struct AISuggestedOpeningCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("🤖")
                    .font(.title3)
                
                Text("AI Suggested Opening")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.cyan)
                
                Spacer()
            }
            
            Text("Since you both love \"Atomic Habits,\" try asking about their favorite habit they're building!")
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.leading)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.cyan.opacity(0.5), lineWidth: 2)
                )
        )
    }
}

struct ChatMessageBubble: View {
    let text: String
    let timestamp: String
    let isCurrentUser: Bool
    var isFirstMessage: Bool = false
    
    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(text)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(isCurrentUser ? Color.blue : Color.white.opacity(0.15))
                    )
                
                Text(timestamp)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 8)
            }
            
            if !isCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }
}

struct AISuggestionsSection: View {
    let suggestions = [
        "Want to be accountability partners? 🤝",
        "Which chapter hit you the most?",
        "Coffee meetup to discuss? ☕"
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("💡 AI suggests:")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
                
                Spacer()
            }
            
            VStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(suggestion) {
                        // Handle suggestion tap
                    }
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
            }
        }
    }
}

struct ChatInputView: View {
    @Binding var messageText: String
    let onSend: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Text input
            TextField("Type a message...", text: $messageText, axis: .vertical)
                .font(.body)
                .foregroundColor(.white)
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
                .lineLimit(1...4)
            
            // Send button
            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.blue)
                    )
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.2))
    }
}

#Preview {
    ChatView(
        conversation: Conversation(
            participantIds: ["user1", "user2"],
            participantNames: ["You", "Alex"],
            messages: [
                ChatMessage(senderId: "user2", senderName: "Alex", text: "Hey! How's it going?"),
                ChatMessage(senderId: "user1", senderName: "You", text: "Pretty good! Just grabbed some coffee. How about you?")
            ],
            lastMessageTimestamp: Date()
        ),
        chatManager: ChatManager()
    )
}
