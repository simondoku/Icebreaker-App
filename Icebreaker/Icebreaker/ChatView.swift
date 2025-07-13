import SwiftUI

// MARK: - Chat Header View

struct RealTimeChatHeaderView: View {
    let name: String
    let matchPercentage: Int
    let distance: String
    let connectionStatus: RealTimeChatConnectionStatus
    let onBackTap: () -> Void
    let onInfoTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Back Button
            Button(action: onBackTap) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.cyan)
            }
            
            // User Avatar
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.purple, .blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(name.prefix(1)))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                )
            
            // User Info
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    Text("\(matchPercentage)% match")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text(distance)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    // Connection status
                    ConnectionStatusDot(status: connectionStatus)
                }
            }
            
            Spacer()
            
            // Info Button
            Button(action: onInfoTap) {
                Image(systemName: "info.circle")
                    .font(.title2)
                    .foregroundColor(.cyan)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.3))
                .background(.ultraThinMaterial)
        )
    }
}

// MARK: - Chat Message Bubble

struct ChatMessageBubble: View {
    let message: RealTimeMessage
    let isFromCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Message bubble
                Text(message.text)
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(isFromCurrentUser ? Color.cyan : Color.white.opacity(0.15))
                    )
                
                // Message info
                HStack(spacing: 8) {
                    Text(formatTime(message.timestamp))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    if isFromCurrentUser {
                        DeliveryStatusIcon(status: message.deliveryStatus)
                    }
                }
                .padding(.horizontal, 8)
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

// MARK: - Typing Indicator

struct TypingIndicatorView: View {
    let userName: String
    @State private var animationOffset: CGFloat = 0
    
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.white.opacity(0.6))
                        .frame(width: 6, height: 6)
                        .offset(y: animationOffset)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                            value: animationOffset
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.15))
            )
            
            Spacer()
        }
        .onAppear {
            animationOffset = -3
        }
        .onDisappear {
            animationOffset = 0
        }
    }
}

// MARK: - AI Suggestions Bar

struct AISuggestionsBar: View {
    let suggestions: [String]
    let onSuggestionTap: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("💡 AI suggests:")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                
                Spacer()
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        Button(action: {
                            onSuggestionTap(suggestion)
                        }) {
                            Text(suggestion)
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(Color.white.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16)
                                                .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                                        )
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 8)
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.2))
        )
    }
}

// MARK: - AI Suggested Opening Card

struct AISuggestedOpeningCard: View {
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("🤖 AI Suggested Opening")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.cyan)
                
                Spacer()
                
                Button("✕") {
                    onDismiss()
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
            }
            
            Text("Since you both love reading and building habits, try asking about their favorite book that changed their daily routine!")
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cyan.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Message Input View

struct MessageInputView: View {
    @Binding var messageText: String
    @FocusState.Binding var isTextFieldFocused: Bool
    let onSend: () -> Void
    let onTypingChanged: (Bool) -> Void
    
    @State private var typingTimer: Timer?
    
    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Text Input
            TextField("Type a message...", text: $messageText, axis: .vertical)
                .font(.body)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
                .focused($isTextFieldFocused)
                .onChange(of: messageText) { _, newValue in
                    handleTypingChange()
                }
                .onSubmit {
                    if canSend {
                        onSend()
                    }
                }
            
            // Send Button
            Button(action: onSend) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(canSend ? Color.cyan : Color.gray)
                    )
            }
            .disabled(!canSend)
            .animation(.easeInOut(duration: 0.2), value: canSend)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(Color.black.opacity(0.3))
                .background(.ultraThinMaterial)
        )
    }
    
    private func handleTypingChange() {
        // Cancel previous timer
        typingTimer?.invalidate()
        
        // Indicate typing started
        onTypingChanged(true)
        
        // Set timer to stop typing indication after 1 second of no typing
        typingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
            onTypingChanged(false)
        }
    }
}
