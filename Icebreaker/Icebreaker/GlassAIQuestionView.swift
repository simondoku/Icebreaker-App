import SwiftUI

struct GlassAIQuestionView: View {
    @EnvironmentObject var questionManager: AIQuestionManager
    @State private var answerText = ""
    @State private var showingAnswerHistory = false
    @State private var isSubmitting = false
    @State private var selectedCategory: AIQuestion.QuestionCategory? = nil
    @State private var showingCategoryPicker = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("AI Daily Questions")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Powered by AI • Personalized for you")
                            .font(.subheadline)
                            .foregroundColor(.cyan.opacity(0.8))
                    }
                    .padding(.top, 20)
                    
                    // AI Status Card
                    AIStatusCard()
                    
                    // Question Generation Controls
                    if questionManager.currentQuestion == nil || !questionManager.hasPendingQuestion {
                        QuestionGenerationCard(
                            selectedCategory: $selectedCategory,
                            showingCategoryPicker: $showingCategoryPicker
                        )
                    }
                    
                    if let question = questionManager.currentQuestion, questionManager.hasPendingQuestion {
                        // Dynamic Question Card
                        DynamicQuestionCard(
                            question: question, 
                            answerText: $answerText, 
                            isSubmitting: $isSubmitting
                        )
                        
                        // Enhanced Action Buttons
                        VStack(spacing: 16) {
                            Button(isSubmitting ? "Analyzing with AI..." : "Submit Answer") {
                                submitAnswerWithAI()
                            }
                            .buttonStyle(ModernPrimaryButtonStyle())
                            .disabled(answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                            
                            HStack(spacing: 12) {
                                Button("Skip Question") {
                                    skipQuestion()
                                }
                                .buttonStyle(ModernSecondaryButtonStyle())
                                .disabled(isSubmitting)
                                
                                Button("New Question") {
                                    generateNewQuestion()
                                }
                                .buttonStyle(ModernSecondaryButtonStyle())
                                .disabled(questionManager.isGeneratingQuestion)
                            }
                        }
                        
                        // AI Enhancement Info
                        AIEnhancementInfoCard()
                        
                    } else if questionManager.isGeneratingQuestion {
                        AIGeneratingCard()
                    } else {
                        NoQuestionView()
                    }
                    
                    // Answer History Button
                    if !questionManager.userAnswers.isEmpty {
                        Button("View Answer History (\(questionManager.userAnswers.count))") {
                            showingAnswerHistory = true
                        }
                        .buttonStyle(ModernSecondaryButtonStyle())
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingAnswerHistory) {
                EnhancedAnswerHistoryView()
            }
            .sheet(isPresented: $showingCategoryPicker) {
                CategoryPickerView(selectedCategory: $selectedCategory)
            }
        }
        .onAppear {
            // Generate initial question if none exists
            if questionManager.currentQuestion == nil && !questionManager.isGeneratingQuestion {
                questionManager.generateDailyQuestion()
            }
        }
    }
    
    private func submitAnswerWithAI() {
        guard !answerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        
        isSubmitting = true
        
        // Submit answer and trigger AI analysis
        questionManager.submitAnswer(answerText)
        
        // Reset form
        answerText = ""
        
        // Simulate processing time for UI feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            isSubmitting = false
        }
    }
    
    private func skipQuestion() {
        questionManager.skipQuestion()
        answerText = ""
    }
    
    private func generateNewQuestion() {
        answerText = ""
        questionManager.generateDailyQuestion(category: selectedCategory)
    }
}

// MARK: - Enhanced UI Components

struct AIStatusCard: View {
    @EnvironmentObject var questionManager: AIQuestionManager
    @StateObject private var aiConfig = AIConfiguration.shared
    
    var body: some View {
        HStack(spacing: 16) {
            // AI Status Indicator
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: aiConfig.isAPIConfigured ? [.green, .cyan] : [.orange, .yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .shadow(color: aiConfig.isAPIConfigured ? .cyan.opacity(0.5) : .orange.opacity(0.5), radius: 8)
                
                Image(systemName: aiConfig.isAPIConfigured ? "brain.head.profile" : "exclamationmark.triangle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("DeepSeek AI")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(aiConfig.isAPIConfigured ? .green : .orange)
                        .frame(width: 8, height: 8)
                    
                    Text(aiConfig.isAPIConfigured ? "Active & Learning" : "Configuration Needed")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("Today")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                
                Text("\(questionManager.userAnswers.filter { Calendar.current.isDateInToday($0.createdAt) }.count) answers")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.cyan)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

struct QuestionGenerationCard: View {
    @EnvironmentObject var questionManager: AIQuestionManager
    @Binding var selectedCategory: AIQuestion.QuestionCategory?
    @Binding var showingCategoryPicker: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Generate New Question")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("AI will create a personalized question based on your history")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
            }
            
            HStack(spacing: 12) {
                Button(selectedCategory?.emoji ?? "🎲") {
                    showingCategoryPicker = true
                }
                .font(.title2)
                .frame(width: 50, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                )
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Category")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text(selectedCategory?.displayName ?? "Any Category")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Button("Generate") {
                    questionManager.generateDailyQuestion(category: selectedCategory)
                }
                .buttonStyle(ModernPrimaryButtonStyle())
                .frame(width: 100)
                .disabled(questionManager.isGeneratingQuestion)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct DynamicQuestionCard: View {
    let question: AIQuestion
    @Binding var answerText: String
    @Binding var isSubmitting: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            // Question Display Card with AI indicator
            VStack(spacing: 16) {
                // AI Generation Badge
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.cyan)
                    Text("AI GENERATED • \(question.category.displayName.uppercased())")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.cyan)
                        .tracking(1)
                    Spacer()
                    Text(question.createdAt, style: .time)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                
                // Question Text with enhanced styling
                Text(question.text)
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 8)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [Color.cyan.opacity(0.1), Color.blue.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                    )
            )
            
            // Enhanced Answer Input
            VStack(spacing: 12) {
                HStack {
                    Text("Your Answer")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    Spacer()
                    if isSubmitting {
                        HStack(spacing: 4) {
                            ProgressView()
                                .scaleEffect(0.7)
                            Text("AI Analyzing...")
                                .font(.caption)
                                .foregroundColor(.cyan)
                        }
                    } else {
                        Text("Will be used for matching")
                            .font(.caption)
                            .foregroundColor(.cyan.opacity(0.8))
                    }
                }
                
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    isSubmitting ? Color.cyan.opacity(0.8) :
                                    answerText.isEmpty ? Color.white.opacity(0.3) : 
                                    Color.cyan.opacity(0.6), 
                                    lineWidth: 2
                                )
                        )
                        .frame(minHeight: 120)
                    
                    if answerText.isEmpty && !isSubmitting {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Share your authentic thoughts...")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text("Be specific and personal for better AI matching")
                                .font(.caption)
                                .foregroundColor(.cyan.opacity(0.7))
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    
                    TextEditor(text: $answerText)
                        .font(.body)
                        .foregroundColor(.white)
                        .background(Color.clear)
                        .frame(minHeight: 120)
                        .padding(12)
                        .disabled(isSubmitting)
                        .scrollContentBackground(.hidden)
                }
                
                // Character count and AI tips
                HStack {
                    Text("💡 AI works best with 50+ characters")
                        .font(.caption)
                        .foregroundColor(.cyan.opacity(0.7))
                    
                    Spacer()
                    
                    Text("\(answerText.count) characters")
                        .font(.caption)
                        .foregroundColor(answerText.count >= 50 ? .green : .white.opacity(0.5))
                        .fontWeight(answerText.count >= 50 ? .medium : .regular)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.03))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
    }
}

struct AIGeneratingCard: View {
    @EnvironmentObject var questionManager: AIQuestionManager
    
    var body: some View {
        VStack(spacing: 20) {
            // Animated AI thinking indicator
            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Circle()
                            .stroke(Color.cyan, lineWidth: 2)
                            .frame(width: 80, height: 80)
                            .rotationEffect(.degrees(questionManager.isGeneratingQuestion ? 360 : 0))
                            .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: questionManager.isGeneratingQuestion)
                    )
                
                Text("🤖")
                    .font(.system(size: 32))
            }
            
            VStack(spacing: 8) {
                Text("AI is crafting your question...")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text("Analyzing your history and preferences to create the perfect question")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .cyan))
                .scaleEffect(1.2)
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct AIEnhancementInfoCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.title2)
                .foregroundColor(.cyan)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Enhancement Active")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text("Your answer will be analyzed to improve match quality and generate conversation starters")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
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

struct EnhancedAnswerHistoryView: View {
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

struct CategoryPickerView: View {
    @Binding var selectedCategory: AIQuestion.QuestionCategory?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedBackground()
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // Header
                        VStack(spacing: 8) {
                            Text("Choose Category")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Select a topic for your AI-generated question")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.top, 20)
                        
                        // Any Category Option
                        CategoryOption(
                            emoji: "🎲",
                            title: "Any Category",
                            description: "Let AI choose the best topic for you",
                            isSelected: selectedCategory == nil
                        ) {
                            selectedCategory = nil
                            dismiss()
                        }
                        
                        // Category Options
                        ForEach(AIQuestion.QuestionCategory.allCases, id: \.self) { category in
                            CategoryOption(
                                emoji: category.emoji,
                                title: category.displayName,
                                description: getCategoryDescription(category),
                                isSelected: selectedCategory == category
                            ) {
                                selectedCategory = category
                                dismiss()
                            }
                        }
                        
                        Spacer(minLength: 50)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.cyan)
                }
            }
        }
    }
    
    private func getCategoryDescription(_ category: AIQuestion.QuestionCategory) -> String {
        switch category {
        case .lifestyle:
            return "Questions about your daily life, habits, and personal style"
        case .food:
            return "Culinary preferences, cooking experiences, and food adventures"
        case .books:
            return "Reading habits, favorite genres, and literary discussions"
        case .goals:
            return "Personal aspirations, achievements, and future plans"
        case .daily:
            return "Everyday experiences and current thoughts"
        }
    }
}

struct CategoryOption: View {
    let emoji: String
    let title: String
    let description: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Text(emoji)
                    .font(.system(size: 32))
                    .frame(width: 50, height: 50)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isSelected ? Color.cyan.opacity(0.2) : Color.white.opacity(0.05))
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.cyan)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.cyan.opacity(0.1) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.cyan.opacity(0.5) : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Modern Button Styles
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

#Preview {
    GlassAIQuestionView()
        .environmentObject(AIQuestionManager())
}
