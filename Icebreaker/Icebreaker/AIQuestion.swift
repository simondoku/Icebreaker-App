import Foundation

struct AIQuestion: Identifiable, Codable {
    var id: UUID
    let text: String
    let category: QuestionCategory
    var createdAt: Date
    
    // Custom initializer for creating new questions
    init(text: String, category: QuestionCategory) {
        self.id = UUID()
        self.text = text
        self.category = category
        self.createdAt = Date()
    }
    
    // Codable initializer for decoding from storage
    init(id: UUID, text: String, category: QuestionCategory, createdAt: Date) {
        self.id = id
        self.text = text
        self.category = category
        self.createdAt = createdAt
    }
    
    enum QuestionCategory: String, CaseIterable, Codable {
        case lifestyle = "LIFESTYLE"
        case food = "FOOD"
        case books = "BOOKS"
        case goals = "GOALS"
        case daily = "DAILY"
        
        var emoji: String {
            switch self {
            case .lifestyle: return "🏠"
            case .food: return "🍜"
            case .books: return "📚"
            case .goals: return "🎯"
            case .daily: return "☀️"
            }
        }
        
        var displayName: String {
            return rawValue.capitalized
        }
    }
}

struct AIAnswer: Identifiable, Codable {
    var id: UUID
    let questionId: UUID
    let text: String
    var createdAt: Date
    
    // Custom initializer for creating new answers
    init(questionId: UUID, text: String) {
        self.id = UUID()
        self.questionId = questionId
        self.text = text
        self.createdAt = Date()
    }
    
    // Codable initializer for decoding from storage
    init(id: UUID, questionId: UUID, text: String, createdAt: Date) {
        self.id = id
        self.questionId = questionId
        self.text = text
        self.createdAt = createdAt
    }
    
    // Simple matching - in real app this would be more sophisticated
    func similarity(to other: AIAnswer) -> Double {
        let words1 = Set(text.lowercased().components(separatedBy: .whitespacesAndNewlines))
        let words2 = Set(other.text.lowercased().components(separatedBy: .whitespacesAndNewlines))
        
        let commonWords = words1.intersection(words2)
        let totalWords = words1.union(words2)
        
        return totalWords.isEmpty ? 0 : Double(commonWords.count) / Double(totalWords.count)
    }
}

// AI Question Manager
class AIQuestionManager: ObservableObject {
    @Published var currentQuestion: AIQuestion?
    @Published var userAnswers: [AIAnswer] = []
    @Published var hasPendingQuestion = true
    
    // Sample questions - in real app these would come from your AI backend
    private let sampleQuestions: [AIQuestion] = [
        AIQuestion(text: "What book are you reading right now, and what's the most interesting thing you've learned from it so far?", category: .books),
        AIQuestion(text: "What food did you try for the first time this week?", category: .food),
        AIQuestion(text: "What was the first thing you did this morning?", category: .daily),
        AIQuestion(text: "What's one small habit you're trying to build this month?", category: .lifestyle),  // Fixed: added .lifestyle
        AIQuestion(text: "If you could learn any skill instantly, what would it be and why?", category: .goals),
        AIQuestion(text: "What's your go-to comfort food when you've had a long day?", category: .food),
        AIQuestion(text: "What's the last thing that made you laugh out loud?", category: .daily),
        AIQuestion(text: "What's one place you've never been but really want to visit?", category: .lifestyle)
    ]
    
    init() {
        loadAnswers()
        generateDailyQuestion()
    }
    
    func generateDailyQuestion() {
        // Simple logic - pick a random question for now
        // In real app, AI would generate personalized questions
        currentQuestion = sampleQuestions.randomElement()
        hasPendingQuestion = true
    }
    
    func submitAnswer(_ text: String) {
        guard let question = currentQuestion else { return }
        
        let answer = AIAnswer(
            questionId: question.id,
            text: text
        )
        
        userAnswers.append(answer)
        saveAnswers()
        
        currentQuestion = nil
        hasPendingQuestion = false
        
        // Schedule next question (for demo, we'll allow immediate new questions)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.scheduleNextQuestion()
        }
    }
    
    func skipQuestion() {
        currentQuestion = nil
        hasPendingQuestion = false
        
        // Still schedule next question but with longer delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.scheduleNextQuestion()
        }
    }
    
    private func scheduleNextQuestion() {
        // For demo - generate new question after a delay
        // In real app, this would be based on time intervals (daily, etc.)
        generateDailyQuestion()
    }
    
    private func saveAnswers() {
        if let encoded = try? JSONEncoder().encode(userAnswers) {
            UserDefaults.standard.set(encoded, forKey: "userAnswers")
        }
    }
    
    private func loadAnswers() {
        if let data = UserDefaults.standard.data(forKey: "userAnswers"),
           let answers = try? JSONDecoder().decode([AIAnswer].self, from: data) {
            userAnswers = answers
        }
    }
    
    // Calculate match percentage with another user's answers
    func calculateMatch(with otherAnswers: [AIAnswer]) -> Double {
        guard !userAnswers.isEmpty && !otherAnswers.isEmpty else { return 0 }
        
        var totalSimilarity = 0.0
        var comparisons = 0
        
        for userAnswer in userAnswers {
            for otherAnswer in otherAnswers {
                if userAnswer.questionId == otherAnswer.questionId {
                    totalSimilarity += userAnswer.similarity(to: otherAnswer)
                    comparisons += 1
                }
            }
        }
        
        return comparisons > 0 ? (totalSimilarity / Double(comparisons)) * 100 : 0
    }
}
