//
//  AIDebugView.swift
//  Icebreaker
//
//  Created by Simon Doku on 6/25/25.
//

import SwiftUI
import Combine

struct AIDebugView: View {
    @StateObject private var debugManager = AIDebugManager()
    @State private var testAnswer1 = "I love reading science fiction books"
    @State private var testAnswer2 = "I enjoy sci-fi novels and fantasy stories"
    @State private var testQuestion = "What's your favorite book genre?"
    @State private var showingResults = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("🤖 AI Debug Console")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Test AI integration and API responses")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 20)
                    
                    // API Configuration Status
                    APIStatusCard()
                    
                    // Question Generation Test
                    DebugQuestionGenerationCard(debugManager: debugManager)
                    
                    // Compatibility Analysis Test
                    CompatibilityTestCard(
                        debugManager: debugManager,
                        testAnswer1: $testAnswer1,
                        testAnswer2: $testAnswer2,
                        testQuestion: $testQuestion
                    )
                    
                    // Match Engine Test
                    MatchEngineTestCard(debugManager: debugManager)
                    
                    // AI Usage Statistics
                    UsageStatsCard()
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
        }
        .background(AnimatedBackground().ignoresSafeArea())
        .navigationTitle("AI Debug")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct APIStatusCard: View {
    @StateObject private var aiConfig = AIConfiguration.shared
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "gear.circle.fill")
                        .foregroundColor(.cyan)
                        .font(.title2)
                    
                    Text("API Configuration")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Circle()
                        .fill(aiConfig.isAPIConfigured ? .green : .red)
                        .frame(width: 12, height: 12)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    StatusRow(title: "Provider", value: aiConfig.currentProvider == .deepseek ? "DeepSeek" : "OpenAI")
                    StatusRow(title: "API Key", value: aiConfig.isAPIConfigured ? "✅ Configured" : "❌ Missing")
                    StatusRow(title: "Daily Questions", value: "\(aiConfig.dailyQuestionLimit) limit")
                    StatusRow(title: "Match Analysis", value: "\(aiConfig.matchAnalysisLimit) limit")
                }
                
                if !aiConfig.isAPIConfigured {
                    Text("⚠️ Add your API key to Info.plist or environment variables")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.top, 8)
                }
            }
        }
    }
}

struct DebugQuestionGenerationCard: View {
    @ObservedObject var debugManager: AIDebugManager
    @State private var selectedCategory: AIQuestion.QuestionCategory = .books
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.purple)
                        .font(.title2)
                    
                    Text("Question Generation")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                VStack(spacing: 12) {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(AIQuestion.QuestionCategory.allCases, id: \.self) { category in
                            Text("\(category.emoji) \(category.displayName)")
                                .tag(category)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .foregroundColor(.white)
                    
                    Button("Generate AI Question") {
                        debugManager.testQuestionGeneration(category: selectedCategory)
                    }
                    .buttonStyle(GlassButtonStyle())
                    .disabled(debugManager.isTestingQuestion)
                    
                    if debugManager.isTestingQuestion {
                        ProgressView("Generating...")
                            .foregroundColor(.cyan)
                    }
                    
                    if let question = debugManager.generatedQuestion {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Generated Question:")
                                .font(.caption)
                                .foregroundColor(.cyan)
                            
                            Text(question.text)
                                .font(.body)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    
                    if let error = debugManager.lastError {
                        Text("Error: \(error)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        }
    }
}

struct CompatibilityTestCard: View {
    @ObservedObject var debugManager: AIDebugManager
    @Binding var testAnswer1: String
    @Binding var testAnswer2: String
    @Binding var testQuestion: String
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "heart.circle.fill")
                        .foregroundColor(.pink)
                        .font(.title2)
                    
                    Text("Compatibility Analysis")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Question:")
                            .font(.caption)
                            .foregroundColor(.cyan)
                        TextField("Test question", text: $testQuestion)
                            .textFieldStyle(ModernTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Answer 1:")
                            .font(.caption)
                            .foregroundColor(.cyan)
                        TextField("First answer", text: $testAnswer1)
                            .textFieldStyle(ModernTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Answer 2:")
                            .font(.caption)
                            .foregroundColor(.cyan)
                        TextField("Second answer", text: $testAnswer2)
                            .textFieldStyle(ModernTextFieldStyle())
                    }
                    
                    Button("Analyze Compatibility") {
                        debugManager.testCompatibilityAnalysis(
                            answer1: testAnswer1,
                            answer2: testAnswer2,
                            question: testQuestion
                        )
                    }
                    .buttonStyle(GlassButtonStyle())
                    .disabled(debugManager.isTestingCompatibility)
                    
                    if debugManager.isTestingCompatibility {
                        ProgressView("Analyzing...")
                            .foregroundColor(.cyan)
                    }
                    
                    if let analysis = debugManager.compatibilityResult {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Compatibility Score: \(Int(analysis.score))%")
                                .font(.headline)
                                .foregroundColor(.green)
                            
                            Text("Reason: \(analysis.reason)")
                                .font(.body)
                                .foregroundColor(.white)
                            
                            if !analysis.sharedTopics.isEmpty {
                                Text("Shared Topics: \(analysis.sharedTopics.joined(separator: ", "))")
                                    .font(.caption)
                                    .foregroundColor(.cyan)
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
}

struct MatchEngineTestCard: View {
    @ObservedObject var debugManager: AIDebugManager
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "radar")
                        .foregroundColor(.green)
                        .font(.title2)
                    
                    Text("Match Engine Test")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                VStack(spacing: 12) {
                    Button("Run Full Match Analysis") {
                        debugManager.testMatchEngine()
                    }
                    .buttonStyle(GlassButtonStyle())
                    .disabled(debugManager.isTestingMatches)
                    
                    if debugManager.isTestingMatches {
                        ProgressView("Finding matches...")
                            .foregroundColor(.cyan)
                    }
                    
                    if !debugManager.testMatches.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Found \(debugManager.testMatches.count) matches:")
                                .font(.headline)
                                .foregroundColor(.cyan)
                            
                            ForEach(debugManager.testMatches.prefix(3), id: \.id) { match in
                                HStack {
                                    Text(match.user.firstName)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(Int(match.matchPercentage))%")
                                        .foregroundColor(.green)
                                        .fontWeight(.bold)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
}

struct UsageStatsCard: View {
    @StateObject private var aiConfig = AIConfiguration.shared
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundColor(.orange)
                        .font(.title2)
                    
                    Text("Usage Statistics")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                VStack(spacing: 8) {
                    HStack {
                        Text("Questions Generated Today:")
                            .foregroundColor(.white)
                        Spacer()
                        Text(aiConfig.canGenerateQuestion() ? "Available" : "Limit Reached")
                            .foregroundColor(aiConfig.canGenerateQuestion() ? .green : .red)
                    }
                    
                    HStack {
                        Text("Match Analyses Today:")
                            .foregroundColor(.white)
                        Spacer()
                        Text(aiConfig.canAnalyzeMatch() ? "Available" : "Limit Reached")
                            .foregroundColor(aiConfig.canAnalyzeMatch() ? .green : .red)
                    }
                }
            }
        }
    }
}

struct StatusRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title + ":")
                .foregroundColor(.white.opacity(0.7))
            Spacer()
            Text(value)
                .foregroundColor(.white)
                .fontWeight(.medium)
        }
        .font(.caption)
    }
}

struct ModernTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .foregroundColor(.white)
            .padding(12)
            .background(Color.white.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - Debug Manager
class AIDebugManager: ObservableObject {
    @Published var isTestingQuestion = false
    @Published var isTestingCompatibility = false
    @Published var isTestingMatches = false
    
    @Published var generatedQuestion: AIQuestion?
    @Published var compatibilityResult: CompatibilityAnalysis?
    @Published var testMatches: [MatchResult] = []
    
    @Published var lastError: String?
    
    private let aiService = AIService.shared
    @MainActor private var matchEngine: MatchEngine?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        Task { @MainActor in
            self.matchEngine = MatchEngine()
        }
    }
    
    func testQuestionGeneration(category: AIQuestion.QuestionCategory) {
        isTestingQuestion = true
        lastError = nil
        
        aiService.generatePersonalizedQuestion(
            userHistory: [],
            userPreferences: ["testing", "debug"],
            category: category
        )
        .sink(
            receiveCompletion: { [weak self] completion in
                DispatchQueue.main.async {
                    self?.isTestingQuestion = false
                    if case .failure(let error) = completion {
                        self?.lastError = error.localizedDescription
                        // Fallback to sample question for demo
                        self?.generatedQuestion = AIQuestion(
                            text: "What's your favorite way to spend a weekend? (Fallback question - check API key)",
                            category: category
                        )
                    }
                }
            },
            receiveValue: { [weak self] question in
                DispatchQueue.main.async {
                    self?.generatedQuestion = question
                    self?.isTestingQuestion = false
                }
            }
        )
        .store(in: &cancellables)
    }
    
    func testCompatibilityAnalysis(answer1: String, answer2: String, question: String) {
        isTestingCompatibility = true
        lastError = nil
        
        let aiAnswer1 = AIAnswer(questionId: UUID(), text: answer1)
        let aiAnswer2 = AIAnswer(questionId: UUID(), text: answer2)
        
        aiService.analyzeCompatibility(
            userAnswer: aiAnswer1,
            otherAnswer: aiAnswer2,
            questionText: question
        )
        .sink(
            receiveCompletion: { [weak self] completion in
                DispatchQueue.main.async {
                    self?.isTestingCompatibility = false
                    if case .failure(let error) = completion {
                        self?.lastError = error.localizedDescription
                        // Fallback analysis
                        self?.compatibilityResult = CompatibilityAnalysis(
                            score: 75.0,
                            reason: "Fallback analysis - similar themes detected (check API key)",
                            sharedTopics: ["books", "reading"]
                        )
                    }
                }
            },
            receiveValue: { [weak self] analysis in
                DispatchQueue.main.async {
                    self?.compatibilityResult = analysis
                    self?.isTestingCompatibility = false
                }
            }
        )
        .store(in: &cancellables)
    }
    
    @MainActor func testMatchEngine() {
        isTestingMatches = true
        
        let sampleAnswers = [
            AIAnswer(questionId: UUID(), text: "I love reading science fiction novels"),
            AIAnswer(questionId: UUID(), text: "Coffee is my morning ritual")
        ]
        
        matchEngine?.findMatches(userAnswers: sampleAnswers)
        
        // Monitor match engine state
        matchEngine?.$matches
            .sink { [weak self] matches in
                DispatchQueue.main.async {
                    self?.testMatches = matches
                    if !matches.isEmpty {
                        self?.isTestingMatches = false
                    }
                }
            }
            .store(in: &cancellables)
        
        // Timeout after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if self.isTestingMatches {
                self.isTestingMatches = false
                if self.testMatches.isEmpty {
                    self.lastError = "Match engine test timeout"
                }
            }
        }
    }
}

#Preview {
    AIDebugView()
}
