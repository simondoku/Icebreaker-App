import SwiftUI

struct RealTimeChatView: View {
    let conversation: RealTimeConversation
    @StateObject private var chatManager = RealTimeChatManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var messageText = ""
    @State private var showingSuggestions = true
    @State private var showingAISuggestedOpening = false
    @FocusState private var isTextFieldFocused: Bool
    
    private var otherParticipantName: String {
        conversation.otherParticipantName(currentUserId: "current_user")
    }
    
    private var isOtherUserTyping: Bool {
        conversation.isOtherUserTyping(currentUserId: "current_user")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom Header
            RealTimeChatHeaderView(
                name: otherParticipantName,
                matchPercentage: 92,
                distance: "8m away",
                connectionStatus: chatManager.connectionStatus,
                onBackTap: { dismiss() },
                onInfoTap: { /* Handle info */ }
            )
            
            // Chat Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // AI Suggested Opening (shows at start of conversation)
                        if showingAISuggestedOpening {
                            AISuggestedOpeningCard(
                                onUse: { suggestion in
                                    messageText = suggestion
                                    showingAISuggestedOpening = false
                                }
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                        }
                        
                        // Chat Messages
                        ForEach(conversation.messages) { message in
                            RealTimeChatMessageBubble(
                                message: message,
                                isCurrentUser: message.senderId == "current_user"
                            )
                            .padding(.horizontal, 16)
                            .id(message.id)
                        }
                        
                        // Typing Indicator
                        if isOtherUserTyping {
                            TypingIndicatorView(userName: otherParticipantName)
                                .padding(.horizontal, 16)
                        }
                        
                        // AI Suggestions Section
                        if showingSuggestions && !conversation.messages.isEmpty {
                            AISuggestionsSection(
                                suggestions: chatManager.getMessageSuggestions(for: conversation),
                                onSuggestionTap: { suggestion in
                                    messageText = suggestion
                                    isTextFieldFocused = true
                                }
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
                .onChange(of: conversation.messages.count) {
                    // Auto-scroll to bottom when new message arrives
                    if let lastMessage = conversation.messages.last {
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Message Input Area
            RealTimeChatInputView(
                messageText: $messageText,
                isTyping: $chatManager.isTyping,
                conversationId: conversation.id,
                onSend: sendMessage,
                onTypingChanged: handleTypingChanged
            )
            .focused($isTextFieldFocused)
        }
        .background(Color(red: 0.06, green: 0.06, blue: 0.14))
        .navigationBarHidden(true)
        .onAppear {
            chatManager.setActiveConversation(conversation)
            showingAISuggestedOpening = conversation.messages.isEmpty
        }
        .onDisappear {
            chatManager.setActiveConversation(nil)
        }
    }
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        chatManager.sendMessage(text, to: conversation.id)
        messageText = ""
        showingAISuggestedOpening = false
        showingSuggestions = true
    }
    
    private func handleTypingChanged(_ isTyping: Bool) {
        chatManager.setTypingStatus(isTyping, in: conversation.id)
    }
}

struct RealTimeChatHeaderView: View {
    let name: String
    let matchPercentage: Int
    let distance: String
    let connectionStatus: ConnectionStatus
    let onBackTap: () -> Void
    let onInfoTap: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Button(action: onBackTap) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.cyan)
            }
            
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
                    Text(String(name.prefix(1)).uppercased())
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    Text("\(matchPercentage)% match • \(distance)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    
                    ConnectionStatusIndicator(status: connectionStatus)
                }
            }
            
            Spacer()
            
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

struct ConnectionStatusIndicator: View {
    let status: ConnectionStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    private var statusColor: Color {
        switch status {
        case .connected:
            return .green
        case .connecting, .reconnecting:
            return .orange
        case .disconnected:
            return .red
        }
    }
    
    private var statusText: String {
        switch status {
        case .connected:
            return "Online"
        case .connecting:
            return "Connecting"
        case .reconnecting:
            return "Reconnecting"
        case .disconnected:
            return "Offline"
        }
    }
}

struct AISuggestedOpeningCard: View {
    let onUse: (String) -> Void
    
    private let openingSuggestions = [
        "Hey! I saw you're also into reading. What's the last book that completely changed your perspective? 📚",
        "I noticed we both love coffee! What's your go-to order? ☕",
        "Your travel photos look amazing! What's been your favorite destination so far? ✈️"
    ]
    
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
            
            let suggestion = openingSuggestions.randomElement() ?? openingSuggestions[0]
            
            Text(suggestion)
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.leading)
            
            Button("Use this opener") {
                onUse(suggestion)
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundColor(.cyan)
            .padding(.top, 8)
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

struct RealTimeChatMessageBubble: View {
    let message: RealTimeMessage
    let isCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                HStack {
                    if message.type == .icebreaker {
                        Text("🧊")
                            .font(.caption)
                    }
                    
                    Text(message.text)
                        .font(.body)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(bubbleColor)
                )
                
                HStack(spacing: 4) {
                    Text(formatTimestamp(message.timestamp))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    if isCurrentUser {
                        DeliveryStatusIcon(status: message.deliveryStatus)
                    }
                }
                .padding(.horizontal, 8)
            }
            
            if !isCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }
    
    private var bubbleColor: Color {
        switch message.type {
        case .icebreaker:
            return Color.cyan.opacity(0.8)
        default:
            return isCurrentUser ? Color.blue : Color.white.opacity(0.15)
        }
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct DeliveryStatusIcon: View {
    let status: MessageDeliveryStatus
    
    var body: some View {
        Group {
            switch status {
            case .sending:
                Image(systemName: "clock")
                    .foregroundColor(.white.opacity(0.4))
            case .sent:
                Image(systemName: "checkmark")
                    .foregroundColor(.white.opacity(0.6))
            case .delivered:
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.white.opacity(0.6))
            case .read:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            case .failed:
                Image(systemName: "exclamationmark.circle")
                    .foregroundColor(.red)
            }
        }
        .font(.caption2)
    }
}

struct TypingIndicatorView: View {
    let userName: String
    @State private var animationPhase = 0
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(Color.white.opacity(0.6))
                            .frame(width: 8, height: 8)
                            .opacity(animationPhase == index ? 1.0 : 0.3)
                            .animation(
                                Animation.easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(index) * 0.2),
                                value: animationPhase
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white.opacity(0.15))
                )
                
                Text("\(userName) is typing...")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 8)
            }
            
            Spacer(minLength: 60)
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { _ in
                animationPhase = (animationPhase + 1) % 3
            }
        }
    }
}

struct AISuggestionsSection: View {
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

struct RealTimeChatInputView: View {
    @Binding var messageText: String
    @Binding var isTyping: Bool
    let conversationId: String
    let onSend: () -> Void
    let onTypingChanged: (Bool) -> Void
    
    @State private var typingTimer: Timer?
    
    var body: some View {
        HStack(spacing: 12) {
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
                .onChange(of: messageText) { _, newValue in
                    handleTextChange(newValue)
                }
                .onSubmit {
                    onSend()
                }
            
            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(canSend ? Color.blue : Color.gray)
                    )
            }
            .disabled(!canSend)
            .animation(.easeInOut(duration: 0.2), value: canSend)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.black.opacity(0.2))
    }
    
    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private func handleTextChange(_ newValue: String) {
        let wasTyping = isTyping
        let nowTyping = !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        
        if nowTyping != wasTyping {
            isTyping = nowTyping
            onTypingChanged(nowTyping)
        }
        
        typingTimer?.invalidate()
        if nowTyping {
            typingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                isTyping = false
                onTypingChanged(false)
            }
        }
    }
}

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
            ChatHeaderView(
                name: "Alex",
                matchPercentage: 92,
                distance: "8m away",
                onBackTap: { dismiss() },
                onInfoTap: { /* Handle info */ }
            )
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 16) {
                        if showingAISuggestedOpening {
                            AISuggestedOpeningCard { suggestion in
                                messageText = suggestion
                                showingAISuggestedOpening = false
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                        }
                        
                        VStack(spacing: 12) {
                            ChatMessageBubble(
                                text: "Hey! I saw you're also reading Atomic Habits. Which habit are you working on building right now? 📚",
                                timestamp: "2:34 PM",
                                isCurrentUser: false,
                                isFirstMessage: true
                            )
                            
                            ChatMessageBubble(
                                text: "Perfect! I'm trying to build a consistent morning routine. The 1% better concept is brilliant! 📖",
                                timestamp: "2:35 PM",
                                isCurrentUser: true
                            )
                            
                            ChatMessageBubble(
                                text: "Same here! I've been doing the coffee + journaling combo for 3 weeks now. What does your morning routine look like?",
                                timestamp: "2:36 PM",
                                isCurrentUser: false
                            )
                            
                            ChatMessageBubble(
                                text: "Nice! I start with coffee too, then 10 minutes of reading. Still working on making it automatic 😅",
                                timestamp: "2:37 PM",
                                isCurrentUser: true
                            )
                        }
                        .padding(.horizontal, 16)
                        
                        if showingSuggestions {
                            AISuggestionsSection(
                                suggestions: [
                                    "Want to be accountability partners? 🤝",
                                    "Which chapter hit you the most?",
                                    "Coffee meetup to discuss? ☕"
                                ],
                                onSuggestionTap: { suggestion in
                                    messageText = suggestion
                                }
                            )
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
            }
            
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
            Button(action: onBackTap) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.cyan)
            }
            
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

struct ChatInputView: View {
    @Binding var messageText: String
    let onSend: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
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
