import SwiftUI

// MARK: - Real Time Chat View
struct RealTimeChatView: View {
    let conversation: RealTimeConversation
    @Environment(\.dismiss) private var dismiss
    @State private var messageText = ""
    @State private var messages: [RealTimeMessage] = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Chat Header
                    chatHeader
                    
                    // Messages
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                ChatBubble(message: message, isFromCurrentUser: message.senderId == "current_user")
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .background(Color.black)
                    
                    // Message Input
                    messageInputArea
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                loadDemoMessages()
            }
        }
    }
    
    private var chatHeader: some View {
        HStack(spacing: 16) {
            Button("←") {
                dismiss()
            }
            .font(.title2)
            .foregroundColor(.white)
            
            Circle()
                .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(conversation.participantNames.last?.prefix(1) ?? "?"))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(conversation.participantNames.last ?? "Chat")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Active now")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            
            Spacer()
            
            Button("⋯") {
                // More options
            }
            .font(.title2)
            .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.9))
    }
    
    private var messageInputArea: some View {
        HStack(spacing: 12) {
            HStack(spacing: 8) {
                TextField("Type a message...", text: $messageText)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(Color.white.opacity(0.1))
                    )
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .font(.title2)
                        .foregroundColor(messageText.isEmpty ? .gray : .cyan)
                }
                .disabled(messageText.isEmpty)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.9))
    }
    
    private func loadDemoMessages() {
        messages = [
            RealTimeMessage(senderId: conversation.participantIds.last ?? "", text: "Hey! Great to connect with you! 👋"),
            RealTimeMessage(senderId: "current_user", text: "Hi! I'm excited to chat. I saw we both love reading!"),
            RealTimeMessage(senderId: conversation.participantIds.last ?? "", text: "Yes! What's the last book you read?")
        ]
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let newMessage = RealTimeMessage(
            senderId: "current_user",
            text: messageText
        )
        
        messages.append(newMessage)
        messageText = ""
    }
}

// MARK: - Chat Bubble Component
struct ChatBubble: View {
    let message: RealTimeMessage
    let isFromCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(isFromCurrentUser ? Color.cyan : Color.white.opacity(0.1))
                    )
                
                Text(formatTime(message.timestamp))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 4)
            }
            
            if !isFromCurrentUser {
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