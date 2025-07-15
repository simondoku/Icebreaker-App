import SwiftUI
import FirebaseAuth

// MARK: - Firebase-Powered Real Time Chat View
struct RealTimeChatView: View {
    let conversation: RealTimeConversation
    @Environment(\.dismiss) private var dismiss
    @StateObject private var chatManager = RealTimeChatManager.shared
    
    @State private var messageText = ""
    @State private var isTextFieldFocused = false
    @FocusState private var textFieldFocus: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Chat Header
                    chatHeader
                    
                    // Connection Status (if needed)
                    if chatManager.connectionStatus != .connected {
                        connectionStatusBanner
                    }
                    
                    // Messages
                    messagesScrollView
                    
                    // Typing Indicator
                    if isOtherUserTyping {
                        typingIndicator
                    }
                    
                    // Message Input
                    messageInputArea
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                setupConversation()
            }
            .onDisappear {
                chatManager.setActiveConversation(nil)
            }
        }
    }
    
    // MARK: - View Components
    
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
                    Text(String(otherUserName.prefix(1)))
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(otherUserName)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(userStatusText)
                    .font(.caption)
                    .foregroundColor(userStatusColor)
            }
            
            Spacer()
            
            Button("⋯") {
                // More options - could add block, report, etc.
            }
            .font(.title2)
            .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.black.opacity(0.9))
    }
    
    private var connectionStatusBanner: some View {
        HStack {
            ConnectionStatusDot(status: chatManager.connectionStatus)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
    }
    
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        ChatBubble(
                            message: message, 
                            isFromCurrentUser: message.isFromCurrentUser
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Color.black)
            .onChange(of: messages.count) { _ in
                // Auto-scroll to bottom when new messages arrive
                if let lastMessage = messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
    
    private var typingIndicator: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 6, height: 6)
                        .scaleEffect(typingAnimationScale)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                            value: typingAnimationScale
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color.white.opacity(0.1))
            )
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .onAppear {
            typingAnimationScale = 1.2
        }
    }
    
    @State private var typingAnimationScale: CGFloat = 1.0
    
    private var messageInputArea: some View {
        VStack(spacing: 0) {
            // Error message if present
            if let errorMessage = chatManager.errorMessage {
                HStack {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                    
                    Spacer()
                    
                    Button("Dismiss") {
                        chatManager.errorMessage = nil
                    }
                    .font(.caption)
                    .foregroundColor(.cyan)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            
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
                        .focused($textFieldFocus)
                        .onChange(of: messageText) { newValue in
                            handleTypingChange(newValue)
                        }
                        .onSubmit {
                            sendMessage()
                        }
                    
                    Button(action: sendMessage) {
                        if chatManager.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "paperplane.fill")
                                .font(.title2)
                                .foregroundColor(messageText.isEmpty ? .gray : .cyan)
                        }
                    }
                    .disabled(messageText.isEmpty || chatManager.isLoading)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color.black.opacity(0.9))
    }
    
    // MARK: - Computed Properties
    
    private var otherUserName: String {
        return conversation.otherParticipantName(currentUserId: currentUserId)
    }
    
    private var currentUserId: String {
        return Auth.auth().currentUser?.uid ?? "anonymous"
    }
    
    private var messages: [RealTimeMessage] {
        return chatManager.activeConversation?.messages ?? []
    }
    
    private var isOtherUserTyping: Bool {
        guard let activeConversation = chatManager.activeConversation else { return false }
        return activeConversation.isOtherUserTyping(currentUserId: currentUserId)
    }
    
    private var userStatusText: String {
        switch chatManager.connectionStatus {
        case .connected:
            return isOtherUserTyping ? "typing..." : "Active now"
        case .connecting:
            return "Connecting..."
        case .reconnecting:
            return "Reconnecting..."
        case .disconnected:
            return "Offline"
        }
    }
    
    private var userStatusColor: Color {
        switch chatManager.connectionStatus {
        case .connected:
            return isOtherUserTyping ? .cyan : .green
        case .connecting, .reconnecting:
            return .orange
        case .disconnected:
            return .gray
        }
    }
    
    // MARK: - Methods
    
    private func setupConversation() {
        chatManager.setActiveConversation(conversation)
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        let text = messageText
        messageText = ""
        textFieldFocus = false
        
        Task {
            await chatManager.sendMessage(text, to: conversation.id)
        }
    }
    
    @State private var typingDebounceTimer: Timer?
    
    private func handleTypingChange(_ newValue: String) {
        // Cancel previous timer
        typingDebounceTimer?.invalidate()
        
        // Start typing indicator if not empty
        if !newValue.isEmpty {
            chatManager.setTypingStatus(true, in: conversation.id)
            
            // Set timer to stop typing indicator after 1 second of no typing
            typingDebounceTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                chatManager.setTypingStatus(false, in: conversation.id)
            }
        } else {
            chatManager.setTypingStatus(false, in: conversation.id)
        }
    }
}

// MARK: - Enhanced Chat Bubble Component
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
                
                HStack(spacing: 4) {
                    Text(formatTime(message.timestamp))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    if isFromCurrentUser {
                        DeliveryStatusIcon(status: message.deliveryStatus)
                    }
                }
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