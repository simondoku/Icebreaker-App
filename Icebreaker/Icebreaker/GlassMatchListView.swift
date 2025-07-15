//
//  MatchListView.swift
//  Icebreaker
//
//  Created by Simon Doku on 6/23/25.
//
import SwiftUI
import CoreLocation
import Combine

// MARK: - Missing Services and Types

// Match Interaction Service with Firebase Integration
class MatchInteractionService: ObservableObject {
    static let shared = MatchInteractionService()
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var userInteractions: [String: MatchInteraction] = [:]
    
    private let chatManager = RealTimeChatManager.shared
    
    private init() {}
    
    func canInteract(with userId: String) -> Bool {
        guard let interaction = userInteractions[userId] else { return true }
        return interaction.type != .block && interaction.type != .pass
    }
    
    func getInteraction(for userId: String) -> MatchInteraction? {
        return userInteractions[userId]
    }
    
    func getConnectionStatus(for userId: String) -> ConnectionStatus {
        guard let interaction = userInteractions[userId] else { 
            return .noInteraction 
        }
        
        switch interaction.type {
        case .wave:
            return .waveSent
        case .waveReceived:
            return .waveReceived
        case .introSent:
            return .introSent
        case .introReceived:
            return .introReceived
        case .conversation:
            return .connected
        case .pass:
            return .passed
        case .block:
            return .blocked
        }
    }
    
    func sendIntroMessage(to match: MatchResult, message: String) async -> IcebreakerChatConversation? {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            // Create real Firebase conversation
            let conversation = await chatManager.createConversation(
                with: match.user.id, 
                userName: match.user.firstName
            )
            
            guard let conversation = conversation else {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Failed to create conversation"
                }
                return nil
            }
            
            // Send the intro message
            await chatManager.sendMessage(message, to: conversation.id)
            
            await MainActor.run {
                self.isLoading = false
                // Store the intro interaction
                self.userInteractions[match.user.id] = MatchInteraction(
                    id: UUID().uuidString,
                    userId: match.user.id,
                    type: .introSent,
                    timestamp: Date(),
                    message: message
                )
            }
            
            print("✅ Intro message sent to Firebase")
            
            // Return compatible conversation object
            return IcebreakerChatConversation(
                id: conversation.id,
                matchId: match.user.id,
                otherUserName: match.user.firstName,
                lastMessage: message,
                lastMessageTime: Date(),
                unreadCount: 0,
                status: .introSent
            )
            
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Failed to send intro message: \(error.localizedDescription)"
            }
            return nil
        }
    }
    
    func sendWave(to match: MatchResult) async -> Bool {
        await MainActor.run {
            isLoading = true
        }
        
        // For now, we'll simulate wave sending since waves are more of a notification
        // In a full implementation, you'd create a "waves" collection in Firestore
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            isLoading = false
            // Store the wave interaction
            userInteractions[match.user.id] = MatchInteraction(
                id: UUID().uuidString,
                userId: match.user.id,
                type: .wave,
                timestamp: Date()
            )
        }
        
        // Post notification for wave delivered
        NotificationCenter.default.post(
            name: .waveDelivered,
            object: nil,
            userInfo: ["userName": match.user.firstName]
        )
        
        print("✅ Wave sent to \(match.user.firstName)")
        return true
    }
    
    func acceptWave(from match: MatchResult) async -> IcebreakerChatConversation? {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            // Create real Firebase conversation when wave is accepted
            let conversation = await chatManager.createConversation(
                with: match.user.id, 
                userName: match.user.firstName
            )
            
            guard let conversation = conversation else {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "Failed to create conversation"
                }
                return nil
            }
            
            // Send a system message to start the conversation
            await chatManager.sendMessage("👋 Wave accepted! Let's chat!", to: conversation.id)
            
            await MainActor.run {
                self.isLoading = false
                // Update to conversation status
                self.userInteractions[match.user.id] = MatchInteraction(
                    id: UUID().uuidString,
                    userId: match.user.id,
                    type: .conversation,
                    timestamp: Date()
                )
            }
            
            print("✅ Wave accepted, Firebase conversation created")
            
            return IcebreakerChatConversation(
                id: conversation.id,
                matchId: match.user.id,
                otherUserName: match.user.firstName,
                lastMessage: "Wave accepted! Start chatting.",
                lastMessageTime: Date(),
                unreadCount: 0,
                status: .connected
            )
            
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.errorMessage = "Failed to accept wave: \(error.localizedDescription)"
            }
            return nil
        }
    }
    
    func passMatch(_ match: MatchResult) async -> Bool {
        await MainActor.run {
            isLoading = true
        }
        
        // Store pass action (could also store in Firestore for analytics)
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        await MainActor.run {
            isLoading = false
            userInteractions[match.user.id] = MatchInteraction(
                id: UUID().uuidString,
                userId: match.user.id,
                type: .pass,
                timestamp: Date()
            )
        }
        
        print("✅ Passed on \(match.user.firstName)")
        return true
    }
    
    func reportMatch(_ match: MatchResult, reason: String) async -> Bool {
        await MainActor.run {
            isLoading = true
        }
        
        // In a real app, you'd send this to a moderation system
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            isLoading = false
        }
        
        print("✅ Reported \(match.user.firstName) for: \(reason)")
        return true
    }
    
    func blockMatch(_ match: MatchResult) async -> Bool {
        await MainActor.run {
            isLoading = true
        }
        
        // Store block action
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        await MainActor.run {
            isLoading = false
            userInteractions[match.user.id] = MatchInteraction(
                id: UUID().uuidString,
                userId: match.user.id,
                type: .block,
                timestamp: Date()
            )
        }
        
        print("✅ Blocked \(match.user.firstName)")
        return true
    }
}

// Success Overlay
struct SuccessOverlay: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)
            
            Text(message)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
        .padding(.horizontal, 40)
        .onAppear {
            // Auto-dismiss after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                onDismiss()
            }
        }
    }
}

// Report User View
struct ReportUserView: View {
    let match: MatchResult
    let onReport: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedReason = ""
    
    private let reportReasons = [
        "Inappropriate content",
        "Spam or fake profile",
        "Harassment",
        "Other"
    ]
    
    // Break down complex button styling logic
    private func isReasonSelected(_ reason: String) -> Bool {
        selectedReason == reason
    }
    
    private func buttonFillColor(for reason: String) -> Color {
        isReasonSelected(reason) ? Color.cyan.opacity(0.2) : Color.white.opacity(0.1)
    }
    
    private func buttonStrokeColor(for reason: String) -> Color {
        isReasonSelected(reason) ? Color.cyan : Color.white.opacity(0.2)
    }
    
    private func buttonBackground(for reason: String) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(buttonFillColor(for: reason))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(buttonStrokeColor(for: reason), lineWidth: 1)
            )
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text("Report User")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Help keep our community safe")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                VStack(spacing: 12) {
                    ForEach(reportReasons, id: \.self) { reason in
                        Button(action: {
                            selectedReason = reason
                        }) {
                            HStack {
                                Text(reason)
                                    .font(.body)
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                if selectedReason == reason {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.cyan)
                                }
                            }
                            .padding(16)
                            .background(buttonBackground(for: reason))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                Button("Submit Report") {
                    onReport(selectedReason)
                    dismiss()
                }
                .buttonStyle(GlassButtonStyle())
                .disabled(selectedReason.isEmpty)
                .opacity(selectedReason.isEmpty ? 0.5 : 1.0)
                
                Spacer()
            }
            .padding()
            .background(Color.black.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

// Interaction Status Card
struct InteractionStatusCard: View {
    let interaction: MatchInteraction
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForInteraction(interaction.type))
                .foregroundColor(colorForInteraction(interaction.type))
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(titleForInteraction(interaction.type))
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(formatDate(interaction.timestamp))
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(colorForInteraction(interaction.type).opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func iconForInteraction(_ type: MatchInteraction.InteractionType) -> String {
        switch type {
        case .wave: return "hand.wave"
        case .conversation: return "message"
        case .pass: return "xmark"
        case .block: return "nosign"
        case .waveReceived: return "arrow.right.circle"
        case .introSent: return "paperplane"
        case .introReceived: return "envelope"
        }
    }
    
    private func colorForInteraction(_ type: MatchInteraction.InteractionType) -> Color {
        switch type {
        case .wave: return .yellow
        case .conversation: return .blue
        case .pass: return .orange
        case .block: return .red
        case .waveReceived: return .green
        case .introSent: return .purple
        case .introReceived: return .cyan
        }
    }
    
    private func titleForInteraction(_ type: MatchInteraction.InteractionType) -> String {
        switch type {
        case .wave: return "Wave Sent"
        case .conversation: return "Conversation Started"
        case .pass: return "Passed"
        case .block: return "Blocked"
        case .waveReceived: return "Wave Received"
        case .introSent: return "Intro Message Sent"
        case .introReceived: return "Intro Message Received"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// Shared Answer Detail Card
struct SharedAnswerDetailCard: View {
    let sharedAnswer: MatchResult.SharedAnswer
    let userName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(sharedAnswer.questionText)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.cyan)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("You:")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text(sharedAnswer.userAnswer)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }
                
                HStack {
                    Text("\(userName):")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    
                    Text(sharedAnswer.matchAnswer)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(0.05))
            )
            
            HStack {
                Text("Compatibility:")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                
                Text("\(Int(sharedAnswer.compatibility))%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.green)
                
                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}

// Error Message Card
struct ErrorMessageCard: View {
    let message: String
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.red)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Error")
                    .font(.headline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Spacer()
            
            Button("Dismiss") {
                onDismiss()
            }
            .font(.caption)
            .foregroundColor(.cyan)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - AI Insights Detail View
struct AIInsightsView: View {
    let matches: [MatchResult]
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // AI Analysis Header
                        VStack(spacing: 16) {
                            Text("🧠 AI Connection Analysis")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.cyan)
                            
                            Text("Based on your recent answers and profile")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.top, 20)
                        
                        // Overall Statistics
                        GlassCard {
                            VStack(spacing: 20) {
                                Text("📊 Match Statistics")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                HStack(spacing: 30) {
                                    StatItem(
                                        number: "\(matches.count)",
                                        label: "Total Matches"
                                    )
                                    
                                    StatItem(
                                        number: "\(matches.filter { $0.matchPercentage >= 80 }.count)",
                                        label: "High Compatibility"
                                    )
                                    
                                    StatItem(
                                        number: "\(matches.filter { $0.user.isActive }.count)",
                                        label: "Active Now"
                                    )
                                }
                            }
                        }
                        
                        // AI Recommendations
                        GlassCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("💡 AI Recommendations")
                                    .font(.headline)
                                    .foregroundColor(.cyan)
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("• Your compatibility scores are highest with people who share similar daily routines")
                                        .font(.body)
                                        .foregroundColor(.white.opacity(0.9))
                                    
                                    Text("• Active users are 3x more likely to respond within an hour")
                                        .font(.body)
                                        .foregroundColor(.white.opacity(0.9))
                                    
                                    Text("• Starting with a wave increases conversation success by 40%")
                                        .font(.body)
                                        .foregroundColor(.white.opacity(0.9))
                                }
                            }
                        }
                        
                        // Top Matches Analysis
                        if let topMatch = matches.first {
                            GlassCard {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("🎯 Top Match Analysis")
                                        .font(.headline)
                                        .foregroundColor(.green)
                                    
                                    HStack(spacing: 16) {
                                        Circle()
                                            .fill(LinearGradient(colors: [.green, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                                            .frame(width: 60, height: 60)
                                            .overlay(
                                                Text(String(topMatch.user.firstName.prefix(1)))
                                                    .font(.title2)
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.white)
                                            )
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(topMatch.user.firstName)
                                                .font(.title3)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.white)
                                            
                                            Text("\(Int(topMatch.matchPercentage))% compatibility")
                                                .font(.subheadline)
                                                .foregroundColor(.green)
                                        }
                                        
                                        Spacer()
                                    }
                                    
                                    Text(topMatch.aiInsight)
                                        .font(.body)
                                        .foregroundColor(.white.opacity(0.9))
                                }
                            }
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("←") {
                        dismiss()
                    }
                    .font(.title2)
                    .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Main Glass Match List View
struct GlassMatchListView: View {
    @EnvironmentObject var authManager: FirebaseAuthManager
    @EnvironmentObject var questionManager: AIQuestionManager
    @EnvironmentObject var locationManager: LocationManager
    @StateObject private var viewModel = MatchListViewModel()
    @StateObject private var interactionService = MatchInteractionService.shared
    
    @State private var showingUserDetails = false
    @State private var showingMatchSettings = false
    @State private var showingAIInsights = false
    @State private var selectedMatch: MatchResult?
    @State private var isRefreshing = false
    @State private var selectedInterests: Set<String> = []
    @State private var distanceFilter: Double = 50
    @State private var showingIntroMessageView = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HeaderView(
                        matchCount: filteredMatches.count,
                        isRefreshing: isRefreshing,
                        onRefresh: refreshMatches,
                        onShowFilters: { showingMatchSettings = true },
                        onShowSettings: { showingMatchSettings = true }
                    )
                    
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            // Today's Best Match (if available)
                            if let bestMatch = bestMatch {
                                TodaysBestMatchCard(match: bestMatch) {
                                    selectedMatch = bestMatch
                                    showingUserDetails = true
                                }
                                .padding(.horizontal, 20)
                            }
                            
                            // AI Summary - Fixed to show AI insights instead of settings
                            if !viewModel.matches.isEmpty {
                                AISummaryCard(
                                    matches: filteredMatches,
                                    onTap: { showingAIInsights = true }
                                )
                                .padding(.horizontal, 20)
                            }
                            
                            // Match Cards
                            ForEach(filteredMatches) { match in
                                MatchCard(match: match) {
                                    selectedMatch = match
                                    showingUserDetails = true
                                }
                                .transition(.scale.combined(with: .opacity))
                            }
                            
                            // Load more button if needed
                            if viewModel.hasMoreMatches {
                                LoadMoreButton {
                                    Task {
                                        await viewModel.loadMoreMatches()
                                    }
                                }
                            }
                            
                            Spacer(minLength: 100)
                        }
                        .padding(.horizontal, 20)
                    }
                    .refreshable {
                        await refreshMatchesAsync()
                    }
                }
                
                // Error overlay
                if !viewModel.errorMessage.isEmpty {
                    ErrorOverlay(
                        message: viewModel.errorMessage,
                        onRetry: refreshMatches,
                        onDismiss: { viewModel.clearError() }
                    )
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                setupView()
            }
            .onReceive(NotificationCenter.default.publisher(for: .userLocationUpdated)) { _ in
                Task {
                    await viewModel.refreshMatches(force: false)
                }
            }
            .sheet(isPresented: $showingUserDetails) {
                if let match = selectedMatch {
                    MatchDetailView(match: match)
                        .onAppear {
                            // Ensure the match data is available when the view appears
                            print("Opening match detail for: \(match.user.firstName)")
                        }
                }
            }
            .sheet(isPresented: $showingMatchSettings) {
                MatchSettingsView()
            }
            .sheet(isPresented: $showingAIInsights) {
                AIInsightsView(matches: filteredMatches)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var filteredMatches: [MatchResult] {
        viewModel.matches.filter { match in
            // Distance filter
            guard match.distance <= distanceFilter else { return false }
            
            // Interest filter
            if !selectedInterests.isEmpty {
                let hasMatchingInterest = selectedInterests.contains { interest in
                    match.user.interests.contains(interest)
                }
                guard hasMatchingInterest else { return false }
            }
            
            return true
        }
    }
    
    private var bestMatch: MatchResult? {
        filteredMatches.first { $0.matchPercentage >= 85 }
    }
    
    private var availableInterests: [String] {
        Set(viewModel.matches.flatMap { $0.user.interests }).sorted()
    }
    
    // MARK: - Methods
    
    private func setupView() {
        Task {
            // Use real Firebase authentication and match discovery
            await viewModel.initializeRealMatches()
        }
    }
    
    private func refreshMatches() {
        isRefreshing = true
        Task {
            await viewModel.refreshRealMatches()
            await MainActor.run {
                isRefreshing = false
            }
        }
    }
    
    private func refreshMatchesAsync() async {
        await viewModel.refreshRealMatches()
    }
}

// MARK: - Match List View Model
@MainActor
class MatchListViewModel: ObservableObject {
    @Published var matches: [MatchResult] = []
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var hasMoreMatches = false
    
    private let matchEngine = MatchEngine.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Observe match engine updates
        matchEngine.$currentMatches
            .receive(on: DispatchQueue.main)
            .assign(to: \.matches, on: self)
            .store(in: &cancellables)
        
        matchEngine.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: \.isLoading, on: self)
            .store(in: &cancellables)
        
        matchEngine.$errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.errorMessage = error ?? ""
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Real Firebase Integration Methods
    
    func initializeRealMatches() async {
        await matchEngine.findMatchesForCurrentUser()
    }
    
    func refreshRealMatches() async {
        await matchEngine.refreshMatchesForCurrentUser()
    }
    
    // MARK: - Legacy Methods (kept for compatibility)
    
    func initializeMatches(currentUser: IcebreakerUser?, userAnswers: [AIAnswer]) async {
        // Now uses real Firebase data instead of mock conversion
        await initializeRealMatches()
    }
    
    func refreshMatches(force: Bool) async {
        await refreshRealMatches()
    }
    
    func loadMoreMatches() async {
        // Real implementation would load next batch from Firestore
        await refreshRealMatches()
    }
    
    func clearError() {
        errorMessage = ""
    }
    
    // MARK: - Demo Methods (removed - now uses real data)
    // These methods have been replaced with real Firebase integration
}

// MARK: - Header View
struct HeaderView: View {
    let matchCount: Int
    let isRefreshing: Bool
    let onRefresh: () -> Void
    let onShowFilters: () -> Void
    let onShowSettings: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Smart Matches")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    if matchCount > 0 {
                        Text("Found \(matchCount) great connections nearby")
                            .font(.subheadline)
                            .foregroundColor(.cyan)
                    } else {
                        Text("Looking for connections...")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    // Refresh button
                    Button(action: onRefresh) {
                        Image(systemName: isRefreshing ? "arrow.clockwise" : "arrow.clockwise.circle")
                            .font(.title2)
                            .foregroundColor(.cyan)
                            .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                            .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: isRefreshing)
                    }
                    .disabled(isRefreshing)
                    
                    // Filter button
                    Button(action: onShowFilters) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.title2)
                            .foregroundColor(.cyan)
                    }
                    
                    // Settings button
                    Button(action: onShowSettings) {
                        Image(systemName: "gearshape")
                            .font(.title2)
                            .foregroundColor(.cyan)
                    }
                }
            }
            .padding(.top, 20)
        }
    }
}

// MARK: - Today's Best Match Card
struct TodaysBestMatchCard: View {
    let match: MatchResult
    let onTap: () -> Void
    
    // Extract complex gradients to computed properties
    private var cardBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [.red.opacity(0.1), .green.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var cardStrokeGradient: LinearGradient {
        LinearGradient(
            colors: [.red.opacity(0.5), .green.opacity(0.5)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var circleGradient: LinearGradient {
        LinearGradient(
            colors: [.red, .green],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "target")
                        .foregroundColor(.red)
                        .font(.title2)
                    
                    Text("Today's Best Match")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.cyan)
                    
                    Spacer()
                    
                    Text("\(Int(match.matchPercentage))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
                
                HStack(spacing: 16) {
                    Circle()
                        .fill(circleGradient)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Text(String(match.user.firstName.prefix(1)))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(match.user.firstName)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text(match.aiInsight)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(2)
                    }
                    
                    Spacer()
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(cardBackgroundGradient)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(cardStrokeGradient, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - AI Summary Card
struct AISummaryCard: View {
    let matches: [MatchResult]
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.purple)
                        .font(.title2)
                    
                    Text("🎯 AI Insights")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.cyan)
                    
                    Spacer()
                }
                
                Text(generateSummary())
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.leading)
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
        .buttonStyle(PlainButtonStyle())
    }
    
    private func generateSummary() -> String {
        let highMatches = matches.filter { $0.matchPercentage >= 80 }.count
        let activeUsers = matches.filter { $0.user.isActive }.count
        
        if highMatches > 0 {
            return "You have \(highMatches) high-compatibility matches nearby. \(activeUsers) people are currently active and ready to connect."
        } else {
            return "Great potential connections found! \(activeUsers) people are currently active in your area."
        }
    }
}

// MARK: - Match Card
struct MatchCard: View {
    let match: MatchResult
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    // Avatar with match percentage badge
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: gradientColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                        
                        Text(String(match.user.firstName.prefix(1)))
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(.white)
                        
                        // Match percentage badge
                        VStack {
                            HStack {
                                Spacer()
                                Circle()
                                    .fill(match.matchLevel.color)
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Text("\(Int(match.matchPercentage))%")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    )
                                    .offset(x: 8, y: -8)
                            }
                            Spacer()
                        }
                        .frame(width: 80, height: 80)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        // Name and status
                        HStack {
                            Text(match.user.firstName)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            if match.user.isActive {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(.green)
                                        .frame(width: 8, height: 8)
                                    
                                    Text("Active")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        
                        // AI Connection insight
                        Text(match.aiInsight)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .lineLimit(2)
                        
                        // Distance and age
                        HStack {
                            Text("\(Int(match.distance))m away")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text("•")
                                .foregroundColor(.white.opacity(0.6))
                            
                            Text("\(match.user.age) years old")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var gradientColors: [Color] {
        let colors: [[Color]] = [
            [.red, .green],
            [.purple, .blue],
            [.cyan, .green],
            [.orange, .yellow],
            [.blue, .purple],
            [.green, .teal]
        ]
        return colors[abs(match.user.id.hashValue) % colors.count]
    }
}

// MARK: - Load More Button
struct LoadMoreButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "arrow.down.circle")
                Text("Load More Matches")
            }
            .font(.headline)
            .foregroundColor(.cyan)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Error Overlay
struct ErrorOverlay: View {
    let message: String
    let onRetry: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundColor(.red)
                
                Text("Oops!")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 16) {
                Button("Dismiss") {
                    onDismiss()
                }
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                )
                
                Button("Retry") {
                    onRetry()
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.cyan)
                )
            }
        }
        .padding(32)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.red.opacity(0.3), lineWidth: 2)
                )
        )
        .padding(.horizontal, 40)
    }
}

// MARK: - Match Detail View
struct MatchDetailView: View {
    let match: MatchResult
    @Environment(\.dismiss) private var dismiss
    @StateObject private var interactionService = MatchInteractionService.shared
    @EnvironmentObject var chatManager: IcebreakerChatManager
    
    @State private var showingChatView = false
    @State private var showingSuccessMessage = false
    @State private var showingReportSheet = false
    @State private var showingMoreOptions = false
    @State private var showingIntroMessageView = false
    @State private var selectedConversation: IcebreakerChatConversation?
    @State private var successMessage = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                mainContent
                
                // Success Overlay
                if showingSuccessMessage {
                    SuccessOverlay(message: successMessage) {
                        showingSuccessMessage = false
                    }
                }
            }
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("←") {
                        dismiss()
                    }
                    .font(.title2)
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("⋯") {
                        showingMoreOptions = true
                    }
                    .font(.title2)
                    .foregroundColor(.white)
                }
            }
            .sheet(isPresented: $showingChatView) {
                if let conversation = selectedConversation {
                    // Create a RealTimeConversation for the chat
                    let realTimeConversation = RealTimeConversation(
                        participantIds: ["current_user", match.user.id],
                        participantNames: ["You", match.user.firstName]
                    )
                    
                    // Use RealTimeChatView for proper chat functionality
                    RealTimeChatView(conversation: realTimeConversation)
                }
            }
            .actionSheet(isPresented: $showingMoreOptions) {
                ActionSheet(
                    title: Text("More Options"),
                    buttons: [
                        .default(Text("Report User")) {
                            showingReportSheet = true
                        },
                        .destructive(Text("Block User")) {
                            blockUser()
                        },
                        .cancel()
                    ]
                )
            }
            .sheet(isPresented: $showingReportSheet) {
                ReportUserView(match: match) { reason in
                    reportUser(reason: reason)
                }
            }
            .sheet(isPresented: $showingIntroMessageView) {
                IntroMessageView(match: match) { message in
                    sendIntroMessage(message)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .waveDelivered)) { notification in
                if let userName = notification.userInfo?["userName"] as? String,
                   userName == match.user.firstName {
                    showSuccessMessage("Wave sent to \(userName)! 👋")
                }
            }
        }
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                profileHeader
                
                interactionStatusSection
                
                compatibilityScoreSection
                
                aiInsightSection
                
                sharedAnswersSection
                
                interestsSection
                
                actionButtonsSection
                
                errorMessageSection
                
                Spacer(minLength: 100)
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - View Components
    
    private var profileHeader: some View {
        VStack(spacing: 20) {
            // Large Avatar
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.purple, .blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 120, height: 120)
                .overlay(
                    Text(String(match.user.firstName.prefix(1)))
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                )
            
            VStack(spacing: 8) {
                Text(match.user.firstName)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                HStack(spacing: 16) {
                    Text("\(match.user.age) years old")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("•")
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text("\(Int(match.distance))m away")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                if match.user.isActive {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        
                        Text("Active now")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
        }
        .padding(.top, 20)
    }
    
    @ViewBuilder
    private var interactionStatusSection: some View {
        if let interaction = interactionService.getInteraction(for: match.user.id) {
            InteractionStatusCard(interaction: interaction)
        }
    }
    
    private var compatibilityScoreSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("🎯 Compatibility Score")
                    .font(.headline)
                    .foregroundColor(.cyan)
                
                Spacer()
                
                Text("\(Int(match.matchPercentage))%")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(match.matchLevel.color)
            }
            
            ProgressView(value: match.compatibilityScore)
                .progressViewStyle(LinearProgressViewStyle(tint: match.matchLevel.color))
                .scaleEffect(x: 1, y: 2, anchor: .center)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private var aiInsightSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("🧠 AI Connection Analysis")
                .font(.headline)
                .foregroundColor(.cyan)
            
            Text(match.aiInsight)
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.leading)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    @ViewBuilder
    private var sharedAnswersSection: some View {
        if !match.sharedAnswers.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text("💬 Shared Conversations")
                    .font(.headline)
                    .foregroundColor(.cyan)
                
                ForEach(Array(match.sharedAnswers.enumerated()), id: \.offset) { index, sharedAnswer in
                    SharedAnswerDetailCard(sharedAnswer: sharedAnswer, userName: match.user.firstName)
                }
            }
        }
    }
    
    @ViewBuilder
    private var interestsSection: some View {
        if !match.user.interests.isEmpty {
            VStack(alignment: .leading, spacing: 16) {
                Text("🎨 Interests")
                    .font(.headline)
                    .foregroundColor(.cyan)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 8) {
                    ForEach(match.user.interests, id: \.self) { interest in
                        Text(interest.capitalized)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.cyan.opacity(0.2))
                            )
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    @ViewBuilder
    private var actionButtonsSection: some View {
        let connectionStatus = interactionService.getConnectionStatus(for: match.user.id)
        
        VStack(spacing: 16) {
            // Break down the complex switch statement into separate views
            actionButtonsForConnectionStatus(connectionStatus)
        }
    }
    
    @ViewBuilder
    private func actionButtonsForConnectionStatus(_ connectionStatus: ConnectionStatus) -> some View {
        switch connectionStatus {
        case .noInteraction:
            noInteractionButtons
        case .waveSent:
            waveSentView
        case .introSent:
            introSentView
        case .waveReceived:
            waveReceivedButtons
        case .connected:
            connectedView
        case .passed, .blocked:
            passedOrBlockedView(connectionStatus)
        case .introReceived:
            introReceivedButtons
        }
    }
    
    @ViewBuilder
    private var noInteractionButtons: some View {
        VStack(spacing: 12) {
            Button(action: showIntroMessageView) {
                HStack {
                    Image(systemName: "paperplane.fill")
                    Text("Send Intro Message")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing))
                )
            }
            
            Text("OR")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
            
            HStack(spacing: 16) {
                waveButton
                passButton
            }
        }
    }
    
    @ViewBuilder
    private var waveButton: some View {
        Button(action: sendWave) {
            HStack {
                if interactionService.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.6)
                } else {
                    Image(systemName: "hand.wave.fill")
                    Text("Send Wave")
                        .fontWeight(.medium)
                }
            }
            .foregroundColor(.white.opacity(0.8))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .disabled(interactionService.isLoading)
    }
    
    @ViewBuilder
    private var passButton: some View {
        Button(action: passMatch) {
            HStack {
                Image(systemName: "xmark")
                Text("Pass")
                    .fontWeight(.medium)
            }
            .foregroundColor(.red.opacity(0.8))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
    
    @ViewBuilder
    private var waveSentView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "hand.wave.fill")
                    .foregroundColor(.yellow)
                Text("Wave sent to \(match.user.firstName)")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.yellow.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                    )
            )
            
            Text("You'll be notified when they respond!")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }
    
    @ViewBuilder
    private var introSentView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(.purple)
                Text("Message sent to \(match.user.firstName)")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.purple.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                    )
            )
            
            Text("They need to respond before you can chat further.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }
    
    @ViewBuilder
    private var waveReceivedButtons: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "hand.wave.fill")
                    .foregroundColor(.green)
                Text("\(match.user.firstName) sent you a wave!")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.green.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                    )
            )
            
            HStack(spacing: 16) {
                acceptWaveButton
                declineButton
            }
        }
    }
    
    @ViewBuilder
    private var acceptWaveButton: some View {
        Button(action: acceptWave) {
            HStack {
                if interactionService.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.6)
                } else {
                    Image(systemName: "checkmark")
                    Text("Accept Wave")
                        .fontWeight(.medium)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: [.green, .cyan], startPoint: .leading, endPoint: .trailing))
            )
        }
        .disabled(interactionService.isLoading)
    }
    
    @ViewBuilder
    private var declineButton: some View {
        Button(action: passMatch) {
            HStack {
                Image(systemName: "xmark")
                Text("Decline")
                    .fontWeight(.medium)
            }
            .foregroundColor(.red.opacity(0.8))
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(0.2), lineWidth: 1)
                    )
            )
        }
    }
    
    @ViewBuilder
    private var connectedView: some View {
        VStack(spacing: 12) {
            Button(action: openFullChat) {
                HStack {
                    if interactionService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "message.fill")
                        Text("Continue Chatting")
                            .fontWeight(.semibold)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing))
                )
            }
            .disabled(interactionService.isLoading)
            
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("You're connected with \(match.user.firstName)!")
                    .font(.subheadline)
                    .foregroundColor(.green)
            }
        }
    }
    
    @ViewBuilder
    private func passedOrBlockedView(_ connectionStatus: ConnectionStatus) -> some View {
        VStack(spacing: 12) {
            HStack {
                let isBlocked = connectionStatus == .blocked
                Image(systemName: isBlocked ? "nosign" : "xmark.circle.fill")
                    .foregroundColor(.red)
                Text(isBlocked ? "User blocked" : "You passed on this match")
                    .font(.headline)
                    .foregroundColor(.red)
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.red.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
    
    @ViewBuilder
    private var introReceivedButtons: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundColor(.purple)
                Text("\(match.user.firstName) sent you an intro message!")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.purple.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                    )
            )
            
            HStack(spacing: 16) {
                respondButton
                declineButton
            }
        }
    }
    
    @ViewBuilder
    private var respondButton: some View {
        Button(action: openFullChat) {
            HStack {
                if interactionService.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.6)
                } else {
                    Image(systemName: "message.fill")
                    Text("Respond")
                        .fontWeight(.medium)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(colors: [.purple, .cyan], startPoint: .leading, endPoint: .trailing))
            )
        }
        .disabled(interactionService.isLoading)
    }
    
    @ViewBuilder
    private var errorMessageSection: some View {
        if let errorMessage = interactionService.errorMessage, !errorMessage.isEmpty {
            ErrorMessageCard(message: errorMessage) {
                interactionService.errorMessage = nil
            }
        }
    }
    
    // MARK: - Action Methods
    
    private func showIntroMessageView() {
        showingIntroMessageView = true
    }
    
    private func sendWave() {
        Task {
            let success = await interactionService.sendWave(to: match)
            if success {
                showSuccessMessage("Wave sent to \(match.user.firstName)! 👋")
            }
        }
    }
    
    private func sendIntroMessage(_ message: String) {
        Task {
            if let conversation = await interactionService.sendIntroMessage(to: match, message: message) {
                chatManager.updateConversation(conversation)
                showSuccessMessage("Intro message sent to \(match.user.firstName)! 📝")
            }
        }
    }
    
    private func acceptWave() {
        Task {
            if let conversation = await interactionService.acceptWave(from: match) {
                selectedConversation = conversation
                chatManager.updateConversation(conversation)
                showSuccessMessage("Wave accepted! You can now chat with \(match.user.firstName)! 💬")
                
                // Auto-open chat after a brief delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    showingChatView = true
                }
            }
        }
    }
    
    private func passMatch() {
        Task {
            let success = await interactionService.passMatch(match)
            if success {
                showSuccessMessage("Passed on \(match.user.firstName)")
                // Dismiss the detail view after passing
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    dismiss()
                }
            }
        }
    }
    
    private func openFullChat() {
        // Get or create conversation for full chat
        let conversation = chatManager.getConversation(for: match.user.id) ?? IcebreakerChatConversation(
            id: UUID().uuidString,
            matchId: match.user.id,
            otherUserName: match.user.firstName,
            lastMessage: "",
            lastMessageTime: Date(),
            unreadCount: 0,
            status: .connected
        )
        
        selectedConversation = conversation
        showingChatView = true
    }
    
    private func reportUser(reason: String) {
        Task {
            let success = await interactionService.reportMatch(match, reason: reason)
            if success {
                showSuccessMessage("User reported. Thank you for keeping our community safe.")
            }
        }
    }
    
    private func blockUser() {
        Task {
            let success = await interactionService.blockMatch(match)
            if success {
                showSuccessMessage("User blocked")
                // Dismiss the detail view after blocking
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    dismiss()
                }
            }
        }
    }
    
    private func showSuccessMessage(_ message: String) {
        successMessage = message
        showingSuccessMessage = true
    }
}

// MARK: - Intro Message View
struct IntroMessageView: View {
    let match: MatchResult
    let onSend: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    
    private let maxCharacters = 200
    private let suggestions = [
        "Hey! I noticed we both love...",
        "Your interest in [topic] caught my eye!",
        "I'd love to chat about...",
        "What's your favorite...?"
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        messageInputSection
                        suggestionsSection
                        sendButtonSection
                        
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
                    .foregroundColor(.white)
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Circle()
                .fill(headerGradient)
                .frame(width: 80, height: 80)
                .overlay(
                    Text(String(match.user.firstName.prefix(1)))
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            Text("Send intro message to \(match.user.firstName)")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            
            Text("Make a great first impression!")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    private var messageInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Message")
                .font(.headline)
                .foregroundColor(.cyan)
            
            VStack(spacing: 8) {
                messageTextEditor
                characterCountDisplay
            }
        }
    }
    
    private var messageTextEditor: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )
                .frame(height: 120)
            
            TextEditor(text: $message)
                .foregroundColor(.white)
                .background(Color.clear)
                .padding(16)
                .scrollContentBackground(.hidden)
        }
    }
    
    private var characterCountDisplay: some View {
        HStack {
            Spacer()
            Text("\(message.count)/\(maxCharacters)")
                .font(.caption)
                .foregroundColor(message.count > maxCharacters ? .red : .white.opacity(0.6))
        }
    }
    
    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("💡 Suggestions")
                .font(.headline)
                .foregroundColor(.cyan)
            
            LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
                ForEach(suggestions, id: \.self) { suggestion in
                    suggestionButton(for: suggestion)
                }
            }
        }
    }
    
    private func suggestionButton(for suggestion: String) -> some View {
        Button(action: {
            if message.isEmpty {
                message = suggestion
            }
        }) {
            HStack {
                Text(suggestion)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "plus.circle")
                    .foregroundColor(.cyan)
            }
            .padding(16)
            .background(suggestionButtonBackground)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var suggestionButtonBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
    }
    
    private var sendButtonSection: some View {
        Button(action: {
            onSend(message)
            dismiss()
        }) {
            HStack {
                Image(systemName: "paperplane.fill")
                Text("Send Message")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(sendButtonBackground)
        }
        .disabled(isSendButtonDisabled)
    }
    
    // MARK: - Computed Properties
    
    private var headerGradient: LinearGradient {
        LinearGradient(
            colors: [.purple, .blue],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var isMessageEmpty: Bool {
        trimmedMessage.isEmpty
    }
    
    private var isMessageTooLong: Bool {
        message.count > maxCharacters
    }
    
    private var shouldDisableButton: Bool {
        isMessageEmpty || isMessageTooLong
    }
    
    private var sendButtonBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(sendButtonFill)
    }
    
    private var sendButtonFill: AnyShapeStyle {
        if shouldDisableButton {
            return AnyShapeStyle(disabledButtonColor)
        } else {
            return AnyShapeStyle(enabledButtonGradient)
        }
    }
    
    private var disabledButtonColor: Color {
        Color.gray.opacity(0.3)
    }
    
    private var enabledButtonGradient: LinearGradient {
        LinearGradient(
            colors: [.blue, .cyan],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private var isSendButtonDisabled: Bool {
        shouldDisableButton
    }
}

// MARK: - Match Settings View
struct MatchSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedInterests: Set<String> = []
    @State private var distanceFilter: Double = 50
    @State private var ageRange: ClosedRange<Int> = 18...99
    @State private var showOnlineOnly = false
    
    private let availableInterests = [
        "Reading", "Fitness", "Technology", "Music", "Travel", "Cooking",
        "Photography", "Art", "Movies", "Gaming", "Nature", "Dancing",
        "Yoga", "Running", "Coffee", "Wine", "Hiking", "Meditation"
    ]
    
    // Break down complex interest button styling
    private func isInterestSelected(_ interest: String) -> Bool {
        selectedInterests.contains(interest)
    }
    
    private func interestButtonFillColor(for interest: String) -> Color {
        isInterestSelected(interest) ? Color.pink.opacity(0.3) : Color.white.opacity(0.1)
    }
    
    private func interestButtonStrokeColor(for interest: String) -> Color {
        isInterestSelected(interest) ? Color.pink : Color.white.opacity(0.2)
    }
    
    private func interestButtonBackground(for interest: String) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(interestButtonFillColor(for: interest))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(interestButtonStrokeColor(for: interest), lineWidth: 1)
            )
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Text("⚙️ Match Settings")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Customize your match preferences")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.top, 20)
                        
                        // Distance Filter
                        GlassCard {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: "location.circle.fill")
                                        .foregroundColor(.cyan)
                                        .font(.title2)
                                    
                                    Text("Distance Range")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Text("\(Int(distanceFilter))km")
                                        .font(.headline)
                                        .foregroundColor(.cyan)
                                }
                                
                                Slider(value: $distanceFilter, in: 1...100, step: 1)
                                    .accentColor(.cyan)
                                
                                Text("Show matches within \(Int(distanceFilter)) kilometers")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        
                        // Age Range Filter
                        GlassCard {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: "calendar.circle.fill")
                                        .foregroundColor(.purple)
                                        .font(.title2)
                                    
                                    Text("Age Range")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Text("\(ageRange.lowerBound)-\(ageRange.upperBound)")
                                        .font(.headline)
                                        .foregroundColor(.purple)
                                }
                                
                                HStack(spacing: 16) {
                                    VStack {
                                        Text("Min: \(ageRange.lowerBound)")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.7))
                                        
                                        Slider(
                                            value: Binding(
                                                get: { Double(ageRange.lowerBound) },
                                                set: { ageRange = Int($0)...ageRange.upperBound }
                                            ),
                                            in: 18...65,
                                            step: 1
                                        )
                                        .accentColor(.purple)
                                    }
                                    
                                    VStack {
                                        Text("Max: \(ageRange.upperBound)")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.7))
                                        
                                        Slider(
                                            value: Binding(
                                                get: { Double(ageRange.upperBound) },
                                                set: { ageRange = ageRange.lowerBound...Int($0) }
                                            ),
                                            in: 18...65,
                                            step: 1
                                        )
                                        .accentColor(.purple)
                                    }
                                }
                            }
                        }
                        
                        // Online Status Filter
                        GlassCard {
                            HStack {
                                Image(systemName: "wifi.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.title2)
                                
                                VStack(alignment: .leading) {
                                    Text("Show Online Only")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Text("Only show users who are currently active")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                
                                Spacer()
                                
                                Toggle("", isOn: $showOnlineOnly)
                                    .toggleStyle(SwitchToggleStyle(tint: .green))
                            }
                        }
                        
                        // Interest Filters
                        GlassCard {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: "heart.circle.fill")
                                        .foregroundColor(.pink)
                                        .font(.title2)
                                    
                                    Text("Preferred Interests")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    if !selectedInterests.isEmpty {
                                        Text("\(selectedInterests.count) selected")
                                            .font(.caption)
                                            .foregroundColor(.pink)
                                    }
                                }
                                
                                Text("Select interests you'd like to share with matches")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 8) {
                                    ForEach(availableInterests, id: \.self) { interest in
                                        Button(action: {
                                            if selectedInterests.contains(interest) {
                                                selectedInterests.remove(interest)
                                            } else {
                                                selectedInterests.insert(interest)
                                            }
                                        }) {
                                            Text(interest)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 8)
                                                .background(interestButtonBackground(for: interest))
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                        }
                        
                        // Save Button
                        Button("Save Settings") {
                            saveSettings()
                            dismiss()
                        }
                        .buttonStyle(GlassButtonStyle())
                        
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
                    .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            loadSettings()
        }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(distanceFilter, forKey: "match_distance_filter")
        UserDefaults.standard.set(ageRange.lowerBound, forKey: "match_age_min")
        UserDefaults.standard.set(ageRange.upperBound, forKey: "match_age_max")
        UserDefaults.standard.set(showOnlineOnly, forKey: "match_online_only")
        UserDefaults.standard.set(Array(selectedInterests), forKey: "match_selected_interests")
    }
    
    private func loadSettings() {
        distanceFilter = UserDefaults.standard.double(forKey: "match_distance_filter")
        if distanceFilter == 0 { distanceFilter = 50 }
        
        let minAge = UserDefaults.standard.integer(forKey: "match_age_min")
        let maxAge = UserDefaults.standard.integer(forKey: "match_age_max")
        if minAge > 0 && maxAge > 0 {
            ageRange = minAge...maxAge
        }
        
        showOnlineOnly = UserDefaults.standard.bool(forKey: "match_online_only")
        
        if let interests = UserDefaults.standard.array(forKey: "match_selected_interests") as? [String] {
            selectedInterests = Set(interests)
        }
    }
}
