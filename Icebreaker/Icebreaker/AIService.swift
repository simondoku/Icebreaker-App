import Foundation
import Combine

// MARK: - AI Service Configuration
enum AIProvider {
    case deepseek
    
    var baseURL: String {
        switch self {
        case .deepseek:
            return "https://api.deepseek.com"
        }
    }
    
    var model: String {
        switch self {
        case .deepseek:
            return "deepseek-chat"
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

// MARK: - API Error Response
struct APIErrorResponse: Codable {
    let error: APIError
}

struct APIError: Codable {
    let message: String
    let type: String
    let code: String
}

// MARK: - AI Service Errors
enum AIServiceError: Error, LocalizedError {
    case invalidURL
    case invalidAPIKey
    case insufficientBalance
    case apiError(String)
    case noResponse
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid API URL"
        case .invalidAPIKey:
            return "Invalid API key"
        case .insufficientBalance:
            return "Insufficient API balance"
        case .apiError(let message):
            return "API Error: \(message)"
        case .noResponse:
            return "No response from AI service"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - AI Service Manager
class AIService: ObservableObject {
    static let shared = AIService()
    
    private let provider: AIProvider = .deepseek
    private var apiKey: String {
        // Priority order: Environment variable > Bundle > Keychain > Secure fallback
        if let envKey = ProcessInfo.processInfo.environment["AI_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        
        if let bundleKey = Bundle.main.object(forInfoDictionaryKey: "AI_API_KEY") as? String, !bundleKey.isEmpty {
            return bundleKey
        }
        
        // TODO: Implement Keychain storage for production
        // For now, return empty string to prevent accidental API usage with placeholder key
        return ""
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
    
    // MARK: - Generate Context-Aware Chat Suggestions
    func generateChatSuggestions(
        conversationHistory: [RealTimeMessage],
        userProfileId: User,
        matchProfile: User?
    ) -> AnyPublisher<[String], Error> {
        
        // Check if AI suggestions are enabled
        guard UserDefaults.standard.bool(forKey: "ai_suggestions_enabled") else {
            return Just([]).setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        
        let prompt = buildChatSuggestionsPrompt(
            conversationHistory: conversationHistory,
            userProfile: userProfileId,
            matchProfile: matchProfile
        )
        
        return makeAIRequest(prompt: prompt, maxTokens: 300)
            .map { response in
                let content = response.choices.first?.message.content ?? ""
                return self.parseChatSuggestions(content)
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Generate Smart Conversation Starters
    func generateSmartConversationStarter(
        userProfile: User?,
        matchProfile: User?,
        sharedInterests: [String] = []
    ) -> AnyPublisher<String, Error> {
        
        // Check if smart starters are enabled
        guard UserDefaults.standard.bool(forKey: "smart_starters_enabled") else {
            return Just("Hey! How's your day going?").setFailureType(to: Error.self).eraseToAnyPublisher()
        }
        
        let prompt = buildSmartStarterPrompt(
            userProfile: userProfile,
            matchProfile: matchProfile,
            sharedInterests: sharedInterests
        )
        
        return makeAIRequest(prompt: prompt, maxTokens: 200)
            .map { response in
                response.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Hey! How's your day going?"
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Chat Suggestions for Chat Manager
    func generateChatSuggestions(for chatHistory: [RealTimeMessage], partnerUser: User) async throws -> [String] {
        let prompt = buildChatSuggestionsPrompt(
            chatHistory: chatHistory,
            partnerUser: partnerUser
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            makeAIRequest(prompt: prompt, maxTokens: 300)
                .map { response in
                    let content = response.choices.first?.message.content ?? ""
                    return self.parseChatSuggestions(content)
                }
                .sink(
                    receiveCompletion: { completion in
                        switch completion {
                        case .finished:
                            break
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    },
                    receiveValue: { suggestions in
                        continuation.resume(returning: suggestions)
                    }
                )
                .store(in: &cancellables)
        }
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
                    print("🔍 DeepSeek API Response: \(jsonString)")
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
                
                // Try to decode as standard response format
                if let response = try? JSONDecoder().decode(AIResponse.self, from: data) {
                    return response
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
    
    private func buildChatSuggestionsPrompt(
        conversationHistory: [RealTimeMessage],
        userProfile: User,
        matchProfile: User?
    ) -> String {
        var prompt = """
        Generate 3 contextually relevant, engaging conversation suggestions based on the chat history and user profiles. 
        
        Instructions:
        - Keep suggestions natural and conversational
        - Build on the current conversation flow
        - Consider shared interests and compatibility
        - Avoid repetitive or generic responses
        - Each suggestion should be 10-20 words max
        - Return suggestions separated by newlines, no numbering
        
        """
        
        // Add user profile context
        prompt += "\nUser Profile:\n"
        prompt += "- Age: \(userProfile.age)\n"
        if !userProfile.bio.isEmpty {
            prompt += "- Bio: \(userProfile.bio)\n"
        }
        if !userProfile.interests.isEmpty {
            prompt += "- Interests: \(userProfile.interests.joined(separator: ", "))\n"
        }
        
        // Add match profile context
        if let match = matchProfile {
            prompt += "\nMatch Profile:\n"
            prompt += "- Age: \(match.age)\n"
            if !match.bio.isEmpty {
                prompt += "- Bio: \(match.bio)\n"
            }
            if !match.interests.isEmpty {
                prompt += "- Interests: \(match.interests.joined(separator: ", "))\n"
            }
        }
        
        // Add recent conversation context
        prompt += "\nRecent Conversation:\n"
        let recentMessages = Array(conversationHistory.suffix(6)) // Last 6 messages for context
        
        if recentMessages.isEmpty {
            prompt += "No conversation yet - this would be the first message.\n"
        } else {
            for message in recentMessages {
                let sender = message.isFromCurrentUser ? "User" : "Match"
                prompt += "\(sender): \(message.text)\n"
            }
        }
        
        prompt += "\nGenerate 3 contextual suggestions:"
        
        return prompt
    }
    
    private func buildChatSuggestionsPrompt(
        chatHistory: [RealTimeMessage],
        partnerUser: User
    ) -> String {
        var prompt = """
        Generate 3 contextually relevant, engaging conversation suggestions based on the chat history and partner profile. 
        
        Instructions:
        - Keep suggestions natural and conversational
        - Build on the current conversation flow
        - Consider partner's interests and profile
        - Avoid repetitive or generic responses
        - Each suggestion should be 10-20 words max
        - Return suggestions separated by newlines, no numbering
        
        """
        
        // Add partner profile context
        prompt += "\nPartner Profile:\n"
        prompt += "- Name: \(partnerUser.name)\n"
        prompt += "- Age: \(partnerUser.age)\n"
        if !partnerUser.bio.isEmpty {
            prompt += "- Bio: \(partnerUser.bio)\n"
        }
        if !partnerUser.interests.isEmpty {
            prompt += "- Interests: \(partnerUser.interests.joined(separator: ", "))\n"
        }
        
        // Add recent conversation context
        prompt += "\nRecent Conversation:\n"
        let recentMessages = Array(chatHistory.suffix(6)) // Last 6 messages for context
        
        if recentMessages.isEmpty {
            prompt += "No conversation yet - this would be the first message.\n"
        } else {
            for message in recentMessages {
                let sender = message.isFromCurrentUser ? "User" : partnerUser.name
                prompt += "\(sender): \(message.text)\n"
            }
        }
        
        prompt += "\nGenerate 3 contextual suggestions:"
        
        return prompt
    }
    
    private func buildSmartStarterPrompt(
        userProfile: User?,
        matchProfile: User?,
        sharedInterests: [String]
    ) -> String {
        var prompt = """
        Generate a personalized, engaging conversation starter based on the profiles and shared interests.
        
        Requirements:
        - Natural and friendly tone
        - Reference shared interests when possible
        - Avoid generic "how are you" messages
        - Keep it under 20 words
        - Make it a question or engaging statement
        
        """
        
        if !sharedInterests.isEmpty {
            prompt += "\nShared Interests: \(sharedInterests.joined(separator: ", "))\n"
        }
        
        if let user = userProfile {
            prompt += "\nUser Interests: \(user.interests.joined(separator: ", "))\n"
        }
        
        if let match = matchProfile {
            prompt += "\nMatch Interests: \(match.interests.joined(separator: ", "))\n"
            if !match.bio.isEmpty {
                prompt += "Match Bio: \(match.bio)\n"
            }
        }
        
        prompt += "\nGenerate one personalized conversation starter:"
        
        return prompt
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
    
    private func parseChatSuggestions(_ content: String) -> [String] {
        let suggestions = content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && !$0.hasPrefix("1.") && !$0.hasPrefix("2.") && !$0.hasPrefix("3.") }
            .map { suggestion in
                // Remove common prefixes like "- ", "• ", numbers, etc.
                var cleaned = suggestion
                if cleaned.hasPrefix("- ") {
                    cleaned = String(cleaned.dropFirst(2))
                }
                if cleaned.hasPrefix("• ") {
                    cleaned = String(cleaned.dropFirst(2))
                }
                // Remove number prefixes like "1. ", "2. ", etc.
                if let range = cleaned.range(of: #"^\d+\.\s*"#, options: .regularExpression) {
                    cleaned = String(cleaned[range.upperBound...])
                }
                return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
        
        // Return up to 3 suggestions, with fallbacks if needed
        let maxSuggestions = min(3, suggestions.count)
        if maxSuggestions > 0 {
            return Array(suggestions.prefix(maxSuggestions))
        } else {
            // Fallback suggestions if parsing fails
            return [
                "That's interesting! Tell me more about that.",
                "I'd love to hear your thoughts on this.",
                "What's been the highlight of your day?"
            ]
        }
    }
    
    private func processChatSuggestionsResponse(
        chatHistory: [RealTimeMessage],
        content: String
    ) -> [String] {
        let suggestions = content
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // Return up to 3 suggestions, with fallbacks if needed
        let maxSuggestions = min(3, suggestions.count)
        if maxSuggestions > 0 {
            return Array(suggestions.prefix(maxSuggestions))
        } else {
            // Fallback suggestions if parsing fails
            return [
                "That's interesting! Tell me more about that.",
                "I'd love to hear your thoughts on this.",
                "What's been the highlight of your day?"
            ]
        }
    }
}
