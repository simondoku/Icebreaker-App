//
//  AIConfiguration.swift
//  Icebreaker
//
//  Created by Simon Doku on 6/25/25.
//

import Foundation

// MARK: - AI Configuration Manager
class AIConfiguration: ObservableObject {
    static let shared = AIConfiguration()
    
    @Published var currentProvider: AIProvider = .deepseek
    @Published var isAPIConfigured: Bool = false
    @Published var dailyQuestionLimit: Int = 3
    @Published var matchAnalysisLimit: Int = 10
    
    private init() {
        checkAPIConfiguration()
    }
    
    // MARK: - API Configuration
    private func checkAPIConfiguration() {
        // Check if API key is properly configured
        let apiKey = getAPIKey()
        isAPIConfigured = !apiKey.isEmpty && apiKey != "your-api-key-here"
    }
    
    func getAPIKey() -> String {
        // Priority order: Environment variable > Bundle > Keychain > Default
        if let envKey = ProcessInfo.processInfo.environment["AI_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        
        if let bundleKey = Bundle.main.object(forInfoDictionaryKey: "AI_API_KEY") as? String, !bundleKey.isEmpty {
            return bundleKey
        }
        
        // In production, implement Keychain storage
        return "your-api-key-here"
    }
    
    func setAPIKey(_ key: String) {
        // In production, store securely in Keychain
        UserDefaults.standard.set(key, forKey: "temp_api_key")
        checkAPIConfiguration()
    }
    
    // MARK: - Provider Management
    func switchProvider(_ provider: AIProvider) {
        currentProvider = provider
        checkAPIConfiguration()
    }
    
    // MARK: - Usage Limits
    func canGenerateQuestion() -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let questionsToday = UserDefaults.standard.integer(forKey: "questions_\(today.timeIntervalSince1970)")
        return questionsToday < dailyQuestionLimit
    }
    
    func incrementQuestionCount() {
        let today = Calendar.current.startOfDay(for: Date())
        let key = "questions_\(today.timeIntervalSince1970)"
        let current = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(current + 1, forKey: key)
    }
    
    func canAnalyzeMatch() -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        let analysesToday = UserDefaults.standard.integer(forKey: "analyses_\(today.timeIntervalSince1970)")
        return analysesToday < matchAnalysisLimit
    }
    
    func incrementAnalysisCount() {
        let today = Calendar.current.startOfDay(for: Date())
        let key = "analyses_\(today.timeIntervalSince1970)"
        let current = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(current + 1, forKey: key)
    }
    
    // MARK: - AI Prompt Templates
    struct PromptTemplates {
        static let systemPrompt = """
        You are an AI assistant specialized in creating meaningful connections between people through thoughtful questions and compatibility analysis. 
        
        Your responses should be:
        - Authentic and natural
        - Respectful and inclusive
        - Focused on genuine connection
        - Appropriate for a dating context
        - Helpful for fostering real conversations
        """
        
        static let questionGeneration = """
        Generate a thoughtful, engaging question for people to connect authentically.
        
        Requirements:
        - Ask about genuine experiences, thoughts, or preferences
        - Be specific enough to generate meaningful answers
        - Keep under 100 characters
        - Avoid yes/no questions
        - Make it conversational and approachable
        - Focus on positive, constructive topics
        """
        
        static let compatibilityAnalysis = """
        Analyze compatibility between two people based on their answers.
        
        Focus on:
        - Shared values and interests
        - Similar life experiences or goals
        - Complementary perspectives that could create good conversations
        - Communication style compatibility
        - Potential for meaningful connection
        
        Provide constructive insights that help people understand their compatibility.
        """
    }
}

// MARK: - Error Handling
enum AIConfigurationError: Error, LocalizedError {
    case noAPIKey
    case invalidProvider
    case dailyLimitExceeded
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey:
            return "AI API key not configured. Please add your API key in the app settings."
        case .invalidProvider:
            return "Invalid AI provider selected."
        case .dailyLimitExceeded:
            return "Daily AI usage limit exceeded. Please try again tomorrow."
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noAPIKey:
            return "Go to Settings and add your DeepSeek or OpenAI API key."
        case .dailyLimitExceeded:
            return "Upgrade to premium for unlimited AI features."
        default:
            return "Check your internet connection and try again."
        }
    }
}
