import SwiftUI

struct GlassAIQuestionView: View {
    @EnvironmentObject var questionManager: AIQuestionManager
    @State private var answerText = ""
    @State private var showingAnswerHistory = false
    @State private var isSubmitting = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Daily Check-in")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Help AI understand you better")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 20)
                    
                    // AI Assistant Card
                    ModernAICard()
                    
                    if let question = questionManager.currentQuestion {
                        // Question Card - New Design
                        ModernQuestionCard(
                            question: question, 
                            answerText: $answerText, 
                            isSubmitting: $isSubmitting
                        )
                        
                        // Action Buttons - New Design
                        VStack(spacing: 16) {
                            Button("Share My Answer") {
                                submitAnswer()
                            }
                            .buttonStyle(ModernPrimaryButtonStyle())
                            .disabled(answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                            
                            Button("Skip This Question") {
                                skipQuestion()
                            }
                            .buttonStyle(ModernSecondaryButtonStyle())
                            .disabled(isSubmitting)
                        }
                        
                        // Skip Info
                        Text("You can skip up to 3 questions per week. Regular answers improve your matches!")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                    } else {
                        NoQuestionView()
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAnswerHistory) {
                GlassAnswerHistoryView()
            }
        }
    }
    
    private func submitAnswer() {
        guard !answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSubmitting = true
        
        // Simulate processing delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            questionManager.submitAnswer(answerText)
            answerText = ""
            isSubmitting = false
        }
    }
    
    private func skipQuestion() {
        questionManager.skipQuestion()
        answerText = ""
    }
}

// New Modern AI Card Component
struct ModernAICard: View {
    var body: some View {
        HStack(spacing: 16) {
            // AI Avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.cyan, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .shadow(color: .cyan.opacity(0.5), radius: 12)
                
                Text("🤖")
                    .font(.system(size: 28))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Ava AI")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Your personal connection assistant")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// New Modern Question Card
struct ModernQuestionCard: View {
    let question: AIQuestion
    @Binding var answerText: String
    @Binding var isSubmitting: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            // Question Display Card
            VStack(spacing: 16) {
                // Category Badge
                Text("\(question.category.displayName.uppercased()) • TODAY")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.cyan)
                    .tracking(1)
                
                // Question Text
                Text(question.text)
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            
            // Answer Input Card - Enhanced visibility
            VStack(spacing: 12) {
                // Input label
                HStack {
                    Text("Your Answer")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    Spacer()
                    Text("Tap to write...")
                        .font(.caption)
                        .foregroundColor(.cyan.opacity(0.8))
                }
                
                ZStack(alignment: .topLeading) {
                    // Background with enhanced visibility
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    answerText.isEmpty ? 
                                    Color.white.opacity(0.3) : 
                                    Color.cyan.opacity(0.6), 
                                    lineWidth: 2
                                )
                        )
                        .frame(minHeight: 140)
                    
                    if answerText.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Share your thoughts...")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text("Be authentic! This helps me find people with similar interests.")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.4))
                                .multilineTextAlignment(.leading)
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    TextEditor(text: $answerText)
                        .font(.body)
                        .foregroundColor(.white)
                        .background(Color.clear)
                        .frame(minHeight: 140)
                        .padding(16)
                        .disabled(isSubmitting)
                        .scrollContentBackground(.hidden)
                }
                
                // Character count and tips
                HStack {
                    Text("💡 Tip: Be specific and personal for better matches")
                        .font(.caption)
                        .foregroundColor(.cyan.opacity(0.7))
                    
                    Spacer()
                    
                    Text("\(answerText.count) characters")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
        }
    }
}

// New Modern Button Styles
struct ModernPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: [.blue, .cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct ModernSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontWeight(.medium)
            .foregroundColor(.white.opacity(0.8))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct NoQuestionView: View {
    @EnvironmentObject var questionManager: AIQuestionManager
    
    var body: some View {
        GlassCard {
            VStack(spacing: 20) {
                // Success Animation
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 80, height: 80)
                    
                    Text("✅")
                        .font(.system(size: 40))
                }
                
                VStack(spacing: 8) {
                    Text("All caught up!")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("You've answered today's question. Come back tomorrow for a new one, or generate another question to improve your matches!")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                
                Button("Generate New Question") {
                    questionManager.generateDailyQuestion()
                }
                .buttonStyle(GlassButtonStyle())
            }
        }
    }
}

struct GlassAnswerHistoryView: View {
    @EnvironmentObject var questionManager: AIQuestionManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(questionManager.userAnswers.reversed()) { answer in
                            AnswerHistoryCard(answer: answer)
                        }
                    }
                    .padding()
                }
                .navigationTitle("Your Answers")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                        .foregroundColor(.white)
                    }
                }
            }
        }
    }
}

struct AnswerHistoryCard: View {
    let answer: AIAnswer
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                // Date and time
                HStack {
                    Text(answer.createdAt, style: .date)
                        .font(.caption)
                        .foregroundColor(.cyan)
                    
                    Spacer()
                    
                    Text(answer.createdAt, style: .time)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                // Answer text
                Text(answer.text)
                    .font(.body)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                
                // Stats or insights could go here
                HStack {
                    Text("📝")
                        .font(.caption)
                    
                    Text("Used for matching")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Spacer()
                    
                    Text("\(answer.text.count) chars")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
    }
}

#Preview {
    GlassAIQuestionView()
        .environmentObject(AIQuestionManager())
}
