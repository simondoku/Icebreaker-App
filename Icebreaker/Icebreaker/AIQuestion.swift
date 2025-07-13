import Foundation
import SwiftUI
import Combine

// MARK: - AI Analysis Models
struct CompatibilityAnalysis: Codable {
    let score: Double
    let reason: String
    let sharedTopics: [String]
    
    init(score: Double, reason: String, sharedTopics: [String] = []) {
        self.score = score
        self.reason = reason
        self.sharedTopics = sharedTopics
    }
}

// MARK: - AI Question Models
struct AIQuestion: Identifiable, Codable {
    let id: UUID
    let text: String
    let category: QuestionCategory
    let difficulty: QuestionDifficulty
    var createdAt: Date
    
    init(id: UUID = UUID(), text: String, category: QuestionCategory, difficulty: QuestionDifficulty = .medium, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.category = category
        self.difficulty = difficulty
        self.createdAt = createdAt
    }
    
    enum QuestionCategory: String, CaseIterable, Codable {
        case lifestyle = "lifestyle"
        case food = "food"
        case books = "books"
        case goals = "goals"
        case daily = "daily"
        
        var emoji: String {
            switch self {
            case .lifestyle: return "🌟"
            case .food: return "🍕"
            case .books: return "📚"
            case .goals: return "🎯"
            case .daily: return "☀️"
            }
        }
        
        var displayName: String {
            return rawValue.capitalized
        }
    }
    
    enum QuestionDifficulty: String, CaseIterable, Codable {
        case easy, medium, hard
    }
}

// Note: The 'AIAnswer' model is now defined in SharedModels.swift.

// Enhanced AI Question Manager with real AI integration
class AIQuestionManager: ObservableObject {
    @Published var currentQuestion: AIQuestion?
    @Published var userAnswers: [AIAnswer] = []
    @Published var hasPendingQuestion = true
    @Published var isGeneratingQuestion = false
    @Published var isAnalyzingAnswer = false
    
    private let aiService = AIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // Fallback questions for offline/error scenarios
    private let sampleQuestions: [AIQuestion] = [
        AIQuestion(text: "What book are you reading right now, and what's the most interesting thing you've learned from it so far?", category: .books),
        AIQuestion(text: "What food did you try for the first time this week?", category: .food),
        AIQuestion(text: "What was the first thing you did this morning?", category: .daily),
        AIQuestion(text: "What's one small habit you're trying to build this month?", category: .lifestyle),
        AIQuestion(text: "If you could learn any skill instantly, what would it be and why?", category: .goals),
        AIQuestion(text: "What's your go-to comfort food when you've had a long day?", category: .food),
        AIQuestion(text: "What's the last thing that made you laugh out loud?", category: .daily),
        AIQuestion(text: "What's one place you've never been but really want to visit?", category: .lifestyle)
    ]
    
    init() {
        loadAnswers()
        generateDailyQuestion()
    }
    
    // MARK: - AI-Powered Question Generation
    func generateDailyQuestion(category: AIQuestion.QuestionCategory? = nil) {
        isGeneratingQuestion = true
        
        // Try AI generation first
        aiService.generatePersonalizedQuestion(
            userHistory: Array(userAnswers.suffix(5)), // Use last 5 answers for context
            userPreferences: extractUserPreferences(),
            category: category
        )
        .sink(
            receiveCompletion: { [weak self] completion in
                DispatchQueue.main.async {
                    if case .failure(let error) = completion {
                        print("AI question generation failed: \(error)")
                        // Fallback to sample questions
                        self?.useFallbackQuestion(category: category)
                    }
                    self?.isGeneratingQuestion = false
                }
            },
            receiveValue: { [weak self] question in
                DispatchQueue.main.async {
                    self?.currentQuestion = question
                    self?.hasPendingQuestion = true
                    self?.isGeneratingQuestion = false
                }
            }
        )
        .store(in: &cancellables)
    }
    
    private func useFallbackQuestion(category: AIQuestion.QuestionCategory?) {
        DispatchQueue.main.async {
            if let category = category {
                self.currentQuestion = self.sampleQuestions.first { $0.category == category } ?? self.sampleQuestions.randomElement()
            } else {
                self.currentQuestion = self.sampleQuestions.randomElement()
            }
            self.hasPendingQuestion = true
        }
    }
    
    private func extractUserPreferences() -> [String] {
        // Extract common themes from user's previous answers
        let allText = userAnswers.map { $0.text }.joined(separator: " ")
        let words = allText.lowercased().components(separatedBy: .whitespacesAndNewlines)
        
        // Common interest keywords to look for
        let interestKeywords = [
            "reading", "books", "music", "travel", "cooking", "fitness", "meditation",
            "art", "coffee", "hiking", "photography", "movies", "gaming", "technology",
            "nature", "writing", "learning", "yoga", "running", "dancing"
        ]
        
        return interestKeywords.filter { keyword in
            words.contains { $0.contains(keyword) }
        }
    }
    
    func submitAnswer(_ text: String) {
        guard let question = currentQuestion else { return }
        
        let answer = AIAnswer(
            questionId: question.id.uuidString,
            questionText: question.text,
            answer: text
        )
        userAnswers.append(answer)
        saveAnswers()
        
        hasPendingQuestion = false
        currentQuestion = nil
        
        // Generate next question for tomorrow
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.generateDailyQuestion()
        }
    }
    
    func skipQuestion() {
        hasPendingQuestion = false
        currentQuestion = nil
        generateDailyQuestion()
    }
    
    // MARK: - Enhanced Answer Analysis
    func analyzeAnswerCompatibility(
        userAnswer: AIAnswer,
        otherAnswer: AIAnswer,
        questionText: String,
        completion: @escaping (CompatibilityAnalysis) -> Void
    ) {
        isAnalyzingAnswer = true
        
        aiService.analyzeCompatibility(
            userAnswer: userAnswer,
            otherAnswer: otherAnswer,
            questionText: questionText
        )
        .sink(
            receiveCompletion: { [weak self] completionResult in
                if case .failure(let error) = completionResult {
                    print("AI compatibility analysis failed: \(error)")
                    // Fallback to simple analysis
                    let fallbackScore = userAnswer.similarity(to: otherAnswer) * 100
                    let fallbackAnalysis = CompatibilityAnalysis(
                        score: fallbackScore,
                        reason: "Similar responses detected",
                        sharedTopics: []
                    )
                    completion(fallbackAnalysis)
                }
                self?.isAnalyzingAnswer = false
            },
            receiveValue: { [weak self] analysis in
                completion(analysis)
                self?.isAnalyzingAnswer = false
            }
        )
        .store(in: &cancellables)
    }
    
    // MARK: - Data Persistence
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
    
    // MARK: - User Preferences & Settings
    func getAnswerHistory(limit: Int = 10) -> [AIAnswer] {
        return Array(userAnswers.suffix(limit))
    }
    
    func deleteAnswer(_ answer: AIAnswer) {
        userAnswers.removeAll { $0.id == answer.id }
        saveAnswers()
    }
    
    func updateAnswer(_ answer: AIAnswer, newText: String) {
        if let index = userAnswers.firstIndex(where: { $0.id == answer.id }) {
            userAnswers[index] = AIAnswer(
                id: answer.id,
                questionId: answer.questionId,
                questionText: answer.questionText,
                answer: newText
            )
            saveAnswers()
        }
    }
}
