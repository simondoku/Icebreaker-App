//
//  AIDebugView.swift
//  Icebreaker
//
//  Created by Simon Doku on 6/25/25.
//

import SwiftUI
import Combine
import Firebase
import FirebaseFirestore

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
                    
                    // Real User Testing
                    RealUserTestCard(debugManager: debugManager)
                    
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

struct RealUserTestCard: View {
    @ObservedObject var debugManager: AIDebugManager
    @State private var userList: [(id: String, name: String, email: String)] = []
    @State private var selectedUser1: String = ""
    @State private var selectedUser2: String = ""
    @State private var isLoadingUsers = false
    @State private var testResults: String = ""
    
    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "person.2.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                    
                    Text("Real User Testing")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                
                VStack(spacing: 12) {
                    Button("Load Existing Users") {
                        loadExistingUsers()
                    }
                    .buttonStyle(GlassButtonStyle())
                    .disabled(isLoadingUsers)
                    
                    if isLoadingUsers {
                        ProgressView("Loading users...")
                            .foregroundColor(.cyan)
                    }
                    
                    if !userList.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Found \(userList.count) users:")
                                .font(.caption)
                                .foregroundColor(.cyan)
                            
                            ForEach(userList, id: \.id) { user in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(user.name)
                                            .font(.caption)
                                            .foregroundColor(.white)
                                        Text(user.email)
                                            .font(.caption2)
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 8) {
                                        Button("User 1") {
                                            selectedUser1 = user.id
                                        }
                                        .font(.caption2)
                                        .foregroundColor(selectedUser1 == user.id ? .green : .cyan)
                                        
                                        Button("User 2") {
                                            selectedUser2 = user.id
                                        }
                                        .font(.caption2)
                                        .foregroundColor(selectedUser2 == user.id ? .green : .cyan)
                                    }
                                }
                                .padding(.vertical, 4)
                                .padding(.horizontal, 8)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(6)
                            }
                            
                            if !selectedUser1.isEmpty && !selectedUser2.isEmpty && selectedUser1 != selectedUser2 {
                                Button("Test Matching & Chat") {
                                    testRealUserFlow()
                                }
                                .buttonStyle(GlassButtonStyle())
                                .disabled(debugManager.isTestingMatches)
                            }
                        }
                    }
                    
                    if !testResults.isEmpty {
                        ScrollView {
                            Text(testResults)
                                .font(.caption)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.black.opacity(0.3))
                                .cornerRadius(8)
                        }
                        .frame(maxHeight: 200)
                    }
                }
            }
        }
    }
    
    private func loadExistingUsers() {
        isLoadingUsers = true
        userList = []
        
        Task {
            if let matchEngine = debugManager.matchEngine {
                await matchEngine.debugExistingUsers()
                
                // Load user list for UI
                do {
                    let db = Firestore.firestore()
                    let snapshot = try await db.collection("users").getDocuments()
                    
                    let users = snapshot.documents.map { doc in
                        let data = doc.data()
                        return (
                            id: doc.documentID,
                            name: data["firstName"] as? String ?? "Unknown",
                            email: data["email"] as? String ?? "No email"
                        )
                    }
                    
                    await MainActor.run {
                        self.userList = users
                        self.isLoadingUsers = false
                    }
                } catch {
                    await MainActor.run {
                        self.testResults = "Error loading users: \(error.localizedDescription)"
                        self.isLoadingUsers = false
                    }
                }
            }
        }
    }
    
    private func testRealUserFlow() {
        testResults = "🧪 Starting real user test...\n"
        
        Task {
            if let matchEngine = debugManager.matchEngine {
                // Test matching between the two selected users
                await matchEngine.testMatchingBetweenUsers(user1Id: selectedUser1, user2Id: selectedUser2)
                
                // Test conversation creation
                await testConversationFlow()
            }
        }
    }
    
    private func testConversationFlow() async {
        let chatManager = RealTimeChatManager.shared
        
        await MainActor.run {
            testResults += "\n🗨️ Testing conversation creation...\n"
        }
        
        do {
            // Try to create a conversation between the two users
            let user1Name = userList.first { $0.id == selectedUser1 }?.name ?? "User1"
            let user2Name = userList.first { $0.id == selectedUser2 }?.name ?? "User2"
            
            await MainActor.run {
                testResults += "Creating conversation between \(user1Name) and \(user2Name)...\n"
            }
            
            if let conversation = await chatManager.createConversation(with: selectedUser2, userName: user2Name) {
                await MainActor.run {
                    testResults += "✅ Conversation created: \(conversation.id)\n"
                    testResults += "📝 Testing message sending...\n"
                }
                
                // Send a test message
                await chatManager.sendMessage("Hello! This is a test message from the debug console 👋", to: conversation.id)
                
                await MainActor.run {
                    testResults += "✅ Test message sent!\n"
                    testResults += "\n🎉 Real user test completed successfully!\n"
                    testResults += "You can now test the full flow in the app:\n"
                    testResults += "1. Switch between users in the app\n"
                    testResults += "2. Check the radar for matches\n"
                    testResults += "3. Send waves and messages\n"
                    testResults += "4. Test real-time chat\n"
                }
            } else {
                await MainActor.run {
                    testResults += "❌ Failed to create conversation\n"
                }
            }
        } catch {
            await MainActor.run {
                testResults += "❌ Error testing conversation: \(error.localizedDescription)\n"
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
    var matchEngine: MatchEngine? // Made non-private for access
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Initialize match engine on main actor
        matchEngine = MatchEngine.shared
    }
    
    func testQuestionGeneration(category: AIQuestion.QuestionCategory) {
        isTestingQuestion = true
        lastError = nil
        
        aiService.generatePersonalizedQuestion(
            userHistory: [],
            userPreferences: [],
            category: category
        )
        .receive(on: DispatchQueue.main)
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isTestingQuestion = false
                if case .failure(let error) = completion {
                    self?.lastError = error.localizedDescription
                    // Fallback question
                    self?.generatedQuestion = AIQuestion(
                        text: "What's something interesting about \(category.displayName.lowercased()) that you'd love to share?",
                        category: category
                    )
                }
            },
            receiveValue: { [weak self] question in
                self?.generatedQuestion = question
            }
        )
        .store(in: &cancellables)
    }
    
    func testCompatibilityAnalysis(answer1: String, answer2: String, question: String) {
        isTestingCompatibility = true
        lastError = nil
        
        let aiAnswer1 = AIAnswer(
            questionId: "test-question-1",
            questionText: question,
            answer: answer1
        )
        let aiAnswer2 = AIAnswer(
            questionId: "test-question-2", 
            questionText: question,
            answer: answer2
        )
        
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
        lastError = nil
        testMatches = []
        
        let sampleAnswers = [
            AIAnswer(
                questionId: "sample-1",
                questionText: "What's your favorite hobby?",
                answer: "I love reading science fiction novels"
            ),
            AIAnswer(
                questionId: "sample-2", 
                questionText: "What's your morning routine?",
                answer: "Coffee is my morning ritual"
            )
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
        
        // Timeout after 10 seconds with weak self
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            if self?.isTestingMatches == true {
                self?.isTestingMatches = false
                if self?.testMatches.isEmpty == true {
                    self?.lastError = "Match engine test timeout"
                }
            }
        }
    }
}

#Preview {
    AIDebugView()
}
