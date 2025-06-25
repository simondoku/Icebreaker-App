import Foundation
import Combine

// MARK: - AI Service Configuration
enum AIProvider {
    case deepseek
    case openai
    
    var baseURL: String {
        switch self {
        case .deepseek:
            return "https://api.deepseek.com"
        case .openai:
            return "https://api.openai.com/v1"
        }
    }
    
    var model: String {
        switch self {
        case .deepseek:
            return "deepseek-chat" // Updated to match DeepSeek docs
        case .openai:
            return "gpt-3.5-turbo"
        }
    }
}

// MARK: - AI Request/Response Models
struct AIRequest: Codable {
    let model: String
    let messages: [AIMessage]
    let temperature: Double
    let maxTokens: Int?
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

struct AIMessage: Codable {
    let role: String
    let content: String
}

struct AIResponse: Codable {
    let choices: [AIChoice]
    let usage: AIUsage?
}

struct AIChoice: Codable {
    let message: AIMessage
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case message
        case finishReason = "finish_reason"
    }
}

struct AIUsage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

// MARK: - Alternative Response Formats
struct DeepSeekResponse: Codable {
    let choices: [DeepSeekChoice]
    let usage: AIUsage?
}

struct DeepSeekChoice: Codable {
    let message: AIMessage
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case message
        case finishReason = "finish_reason"
    }
}

// MARK: - AI Service Manager
class AIService: ObservableObject {
    static let shared = AIService()
    
    private let provider: AIProvider = .deepseek // Switch back to DeepSeek with correct config
    private var apiKey: String {
        // In production, store this securely in Keychain or environment variables
        return Bundle.main.object(forInfoDictionaryKey: "AI_API_KEY") as? String ?? "your-api-key-here"
    }
    
    private let session = URLSession.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    // MARK: - Generate Personalized Questions
    func generatePersonalizedQuestion(
        userHistory: [AIAnswer],
        userPreferences: [String] = [],
        category: AIQuestion.QuestionCategory? = nil
    ) -> AnyPublisher<AIQuestion, Error> {
        
        let prompt = buildQuestionPrompt(
            userHistory: userHistory,
            preferences: userPreferences,
            category: category
        )
        
        return makeAIRequest(prompt: prompt, maxTokens: 150)
            .map { response in
                let questionText = response.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? "What's something interesting that happened to you today?"
                let selectedCategory = category ?? AIQuestion.QuestionCategory.allCases.randomElement() ?? .daily
                return AIQuestion(text: questionText, category: selectedCategory)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Analyze Answer Compatibility
    func analyzeCompatibility(
        userAnswer: AIAnswer,
        otherAnswer: AIAnswer,
        questionText: String
    ) -> AnyPublisher<CompatibilityAnalysis, Error> {
        
        let prompt = buildCompatibilityPrompt(
            question: questionText,
            answer1: userAnswer.text,
            answer2: otherAnswer.text
        )
        
        return makeAIRequest(prompt: prompt, maxTokens: 300)
            .map { response in
                self.parseCompatibilityResponse(response.choices.first?.message.content ?? "")
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Alternative method name for MatchEngine compatibility
    func analyzeAnswerCompatibility(
        userAnswer: AIAnswer,
        otherAnswer: AIAnswer,
        questionText: String,
        completion: @escaping (CompatibilityAnalysis) -> Void
    ) {
        analyzeCompatibility(userAnswer: userAnswer, otherAnswer: otherAnswer, questionText: questionText)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { analysis in
                    completion(analysis)
                }
            )
            .store(in: &cancellables)
    }
    
    // MARK: - Generate Conversation Starters
    func generateConversationStarter(
        sharedAnswers: [MatchResult.SharedAnswer],
        userName: String,
        matchName: String
    ) -> AnyPublisher<String, Error> {
        
        let prompt = buildConversationPrompt(
            sharedAnswers: sharedAnswers,
            userName: userName,
            matchName: matchName
        )
        
        return makeAIRequest(prompt: prompt, maxTokens: 200)
            .map { response in
                response.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Hey! I noticed we have some things in common. How's your day going?"
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Generate AI Insights
    func generateMatchInsight(
        compatibility: Double,
        sharedAnswers: [MatchResult.SharedAnswer],
        userName: String,
        matchName: String
    ) -> AnyPublisher<String, Error> {
        
        let prompt = buildInsightPrompt(
            compatibility: compatibility,
            sharedAnswers: sharedAnswers,
            userName: userName,
            matchName: matchName
        )
        
        return makeAIRequest(prompt: prompt, maxTokens: 150)
            .map { response in
                response.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? "You share similar interests and perspectives."
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Private Helper Methods
    private func makeAIRequest(prompt: String, maxTokens: Int = 500) -> AnyPublisher<AIResponse, Error> {
        guard let url = URL(string: "\(provider.baseURL)/chat/completions") else {
            return Fail(error: AIServiceError.invalidURL)
                .eraseToAnyPublisher()
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let aiRequest = AIRequest(
            model: provider.model,
            messages: [
                AIMessage(role: "system", content: "You are an AI assistant specialized in creating meaningful connections between people. You understand human psychology and communication patterns."),
                AIMessage(role: "user", content: prompt)
            ],
            temperature: 0.7,
            maxTokens: maxTokens
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(aiRequest)
        } catch {
            return Fail(error: error)
                .eraseToAnyPublisher()
        }
        
        return session.dataTaskPublisher(for: request)
            .map(\.data)
            .handleEvents(receiveOutput: { data in
                // Debug: Print the raw response to understand the structure
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("🔍 AI API Response: \(jsonString)")
                }
            })
            .tryMap { data -> AIResponse in
                // Check for API error responses first
                if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                    switch errorResponse.error.code {
                    case "invalid_request_error":
                        if errorResponse.error.message.contains("Insufficient Balance") {
                            throw AIServiceError.insufficientBalance
                        } else if errorResponse.error.message.contains("Incorrect API key") {
                            throw AIServiceError.invalidAPIKey
                        } else {
                            throw AIServiceError.apiError(errorResponse.error.message)
                        }
                    default:
                        throw AIServiceError.apiError(errorResponse.error.message)
                    }
                }
                
                // Try to decode as standard OpenAI format first
                if let response = try? JSONDecoder().decode(AIResponse.self, from: data) {
                    return response
                }
                
                // If that fails, try DeepSeek format
                if let deepseekResponse = try? JSONDecoder().decode(DeepSeekResponse.self, from: data) {
                    return AIResponse(
                        choices: [AIChoice(
                            message: AIMessage(
                                role: "assistant", 
                                content: deepseekResponse.choices.first?.message.content ?? ""
                            ),
                            finishReason: deepseekResponse.choices.first?.finishReason
                        )],
                        usage: deepseekResponse.usage
                    )
                }
                
                // Try parsing alternative formats
                if let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    print("🔍 Trying to parse alternative format: \(jsonObject)")
                    
                    // Check for common response fields
                    if let content = jsonObject["response"] as? String {
                        return AIResponse(
                            choices: [AIChoice(
                                message: AIMessage(role: "assistant", content: content),
                                finishReason: "stop"
                            )],
                            usage: nil
                        )
                    }
                    
                    if let content = jsonObject["text"] as? String {
                        return AIResponse(
                            choices: [AIChoice(
                                message: AIMessage(role: "assistant", content: content),
                                finishReason: "stop"
                            )],
                            usage: nil
                        )
                    }
                    
                    if let content = jsonObject["output"] as? String {
                        return AIResponse(
                            choices: [AIChoice(
                                message: AIMessage(role: "assistant", content: content),
                                finishReason: "stop"
                            )],
                            usage: nil
                        )
                    }
                }
                
                // If all parsing attempts fail, throw error
                throw AIServiceError.noResponse
            }
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
    }
    
    private func buildQuestionPrompt(
        userHistory: [AIAnswer],
        preferences: [String],
        category: AIQuestion.QuestionCategory?
    ) -> String {
        var prompt = """
        Generate a thoughtful, engaging question for a dating app that helps people connect authentically.
        
        Requirements:
        - Ask about genuine experiences, thoughts, or preferences
        - Be specific enough to generate meaningful answers
        - Keep it under 100 characters
        - Avoid yes/no questions
        - Make it feel natural and conversational
        """
        
        if let category = category {
            prompt += "\n- Focus on the \(category.displayName.lowercased()) category"
        }
        
        if !userHistory.isEmpty {
            let recentAnswers = userHistory.suffix(3).map { $0.text }.joined(separator: ", ")
            prompt += "\n\nUser's recent answers to consider: \(recentAnswers)"
            prompt += "\nGenerate a question that builds on these themes or explores new aspects of their personality."
        }
        
        if !preferences.isEmpty {
            prompt += "\n\nUser interests: \(preferences.joined(separator: ", "))"
        }
        
        prompt += "\n\nReturn only the question text, no additional formatting or explanation."
        
        return prompt
    }
    
    private func buildCompatibilityPrompt(question: String, answer1: String, answer2: String) -> String {
        return """
        Analyze the compatibility between these two answers to the question: "\(question)"
        
        Person 1: "\(answer1)"
        Person 2: "\(answer2)"
        
        Provide a response in this exact format:
        SCORE: [0-100]
        REASON: [brief explanation of why they're compatible or different]
        TOPICS: [shared interests or themes, separated by commas]
        
        Focus on:
        - Shared values and interests
        - Similar life experiences
        - Complementary perspectives
        - Communication style compatibility
        """
    }
    
    private func buildConversationPrompt(
        sharedAnswers: [MatchResult.SharedAnswer],
        userName: String,
        matchName: String
    ) -> String {
        let sharedTopics = sharedAnswers.map { 
            "Q: \($0.questionText)\n\(userName): \($0.userAnswer)\n\(matchName): \($0.matchAnswer)"
        }.joined(separator: "\n\n")
        
        return """
        Create a natural, engaging conversation starter based on these shared interests:
        
        \(sharedTopics)
        
        Requirements:
        - Write from \(userName)'s perspective to \(matchName)
        - Reference specific shared interests naturally
        - Ask an engaging follow-up question
        - Keep it friendly and authentic
        - Maximum 2 sentences
        - Don't be overly enthusiastic or cheesy
        
        Return only the conversation starter text.
        """
    }
    
    private func buildInsightPrompt(
        compatibility: Double,
        sharedAnswers: [MatchResult.SharedAnswer],
        userName: String,
        matchName: String
    ) -> String {
        let topics = sharedAnswers.map { $0.questionText }.prefix(3).joined(separator: ", ")
        
        return """
        Generate a brief insight about why \(userName) and \(matchName) are compatible (\(Int(compatibility))% match).
        
        Their shared topics include: \(topics)
        
        Requirements:
        - One sentence explaining the connection
        - Focus on personality traits or values
        - Be specific about what makes them compatible
        - Keep it positive and encouraging
        - Avoid generic statements
        
        Return only the insight text.
        """
    }
    
    private func parseCompatibilityResponse(_ response: String) -> CompatibilityAnalysis {
        let lines = response.components(separatedBy: .newlines)
        var score: Double = 50.0
        var reason = "Similar interests detected"
        var topics: [String] = []
        
        for line in lines {
            if line.hasPrefix("SCORE:") {
                let scoreText = line.replacingOccurrences(of: "SCORE:", with: "").trimmingCharacters(in: .whitespaces)
                score = Double(scoreText) ?? 50.0
            } else if line.hasPrefix("REASON:") {
                reason = line.replacingOccurrences(of: "REASON:", with: "").trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("TOPICS:") {
                let topicsText = line.replacingOccurrences(of: "TOPICS:", with: "").trimmingCharacters(in: .whitespaces)
                topics = topicsText.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            }
        }
        
        return CompatibilityAnalysis(score: score, reason: reason, sharedTopics: topics)
    }
}

// MARK: - Supporting Types
struct CompatibilityAnalysis {
    let score: Double
    let reason: String
    let sharedTopics: [String]
}

enum AIServiceError: Error, LocalizedError {
    case invalidURL
    case noResponse
    case invalidAPIKey
    case insufficientBalance
    case apiError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .noResponse:
            return "No response from AI service"
        case .invalidAPIKey:
            return "Invalid API key"
        case .insufficientBalance:
            return "Insufficient balance for API request"
        case .apiError(let message):
            return "API error: \(message)"
        }
    }
}

struct APIErrorResponse: Codable {
    let error: APIError
}

struct APIError: Codable {
    let code: String
    let message: String
}
