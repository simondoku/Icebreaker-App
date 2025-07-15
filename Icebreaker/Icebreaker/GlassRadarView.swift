import SwiftUI
import CoreLocation

struct GlassRadarView: View {
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var authManager: FirebaseAuthManager
    @StateObject private var matchEngine = MatchEngine.shared
    @EnvironmentObject var questionManager: AIQuestionManager
    
    @State private var isScanning = true
    @State private var selectedMatch: MatchResult?
    @State private var showingUserDetails = false
    @State private var showingMatchesList = false
    @State private var showingMatchPopup = false
    @State private var selectedUserForPopup: MatchResult?
    @State private var scanToggle = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerView
                    
                    // Radar Section
                    radarSection
                    
                    // Controls
                    controlsSection
                    
                    // AI Insights
                    aiInsightsSection
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
            }
            .navigationBarHidden(true)
            .onAppear {
                setupRadar()
            }
            .refreshable {
                await refreshMatches()
            }
            .sheet(isPresented: $showingUserDetails) {
                if let match = selectedMatch {
                    GlassUserDetailView(match: match)
                }
            }
            .sheet(isPresented: $showingMatchesList) {
                GlassMatchListView()
                    .environmentObject(questionManager)
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Icebreaker")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 8) {
                        Circle()
                            .fill(radarStatusColor)
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isScanning)
                        
                        Text("AI Radar • \(radarStatusText)")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                Spacer()
                
                Button(action: toggleScanning) {
                    Image(systemName: isScanning ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.cyan)
                }
            }
            
            // Real Stats Bar
            HStack(spacing: 20) {
                StatItem(number: "\(matchEngine.currentMatches.count)", label: "Nearby")
                StatItem(number: bestMatchPercentage, label: "Best Match")
                StatItem(number: "\(Int(locationManager.visibilityRange))m", label: "Range")
            }
            .padding(.horizontal)
        }
        .padding(.top, 20)
    }
    
    private var radarSection: some View {
        ZStack {
            // Radar Container
            radarContainer
            
            // Match Popup
            if showingMatchPopup, let match = selectedUserForPopup {
                ZStack {
                    // Background overlay to dismiss popup when tapped
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeOut) {
                                showingMatchPopup = false
                            }
                        }
                    
                    VStack {
                        MatchPopupView(match: match, onDismiss: {
                            withAnimation(.easeOut) {
                                showingMatchPopup = false
                            }
                        })
                        .transition(.asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.8)),
                            removal: .move(edge: .top).combined(with: .opacity)
                        ))
                        .zIndex(1)
                        Spacer()
                    }
                }
            }
        }
    }
    
    private var radarContainer: some View {
        ZStack {
            // Radar sweep view
            RadarSweepView(isActive: isScanning)
                .scaleEffect(scanToggle ? 1.05 : 1.0)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: scanToggle)
            
            // User dots
            userDotsView
            
            // Interactive overlay
            Button(action: {
                showingMatchesList = true
            }) {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 280, height: 280)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .frame(height: 380)
    }
    
    private var userDotsView: some View {
        ForEach(matchEngine.currentMatches.prefix(8), id: \.user.id) { match in
            UserRadarDot(
                match: match,
                isScanning: isScanning,
                onTap: {
                    selectedUserForPopup = match
                    withAnimation(.spring()) {
                        showingMatchPopup = true
                    }
                    
                    // Remove the auto-dismiss timer
                    // Let users interact with the popup without it disappearing
                }
            )
        }
    }
    
    private var controlsSection: some View {
        VStack(spacing: 16) {
            // Visibility Range Control
            visibilityRangeControl
            
            // Broadcasting Toggle
            broadcastingToggle
        }
    }
    
    private var visibilityRangeControl: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Visibility Range")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(Int(locationManager.visibilityRange))m")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.cyan)
            }
            
            SliderView(visibilityRange: $locationManager.visibilityRange)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
    
    private var broadcastingToggle: some View {
        HStack {
            HStack(spacing: 12) {
                Text("🎯")
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Broadcasting Location")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Text(locationManager.isVisible ? "Visible to others" : "Hidden from radar")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring()) {
                    locationManager.toggleVisibility()
                }
            }) {
                toggleView
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(locationManager.isVisible ? Color.cyan.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 2)
                )
        )
    }
    
    private var toggleView: some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(locationManager.isVisible ? Color.cyan : Color.gray.opacity(0.3))
            .frame(width: 60, height: 34)
            .overlay(
                Circle()
                    .fill(Color.white)
                    .frame(width: 30, height: 30)
                    .offset(x: locationManager.isVisible ? 13 : -13)
                    .animation(.spring(response: 0.3), value: locationManager.isVisible)
            )
            .shadow(color: locationManager.isVisible ? .cyan.opacity(0.5) : .clear, radius: 8)
    }
    
    private var aiInsightsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("🧠 AI Insights")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.cyan)
                
                Spacer()
                
                // Add debug buttons
                HStack {
                    Button("🔍 Debug") {
                        Task {
                            await matchEngine.debugCurrentUser()
                            await matchEngine.debugNearbyUsersQuery()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                    
                    Button("🧪 Test Users") {
                        Task {
                            await matchEngine.createTestUsers()
                            await refreshMatches()
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.green)
                }
            }
            
            Text(generateAIInsight())
                .font(.body)
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.leading)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 2)
                )
        )
    }
    
    // MARK: - Real Data Helper Methods
    
    private func setupRadar() {
        // Request location permission
        locationManager.requestLocationPermission()
        
        // Start finding real matches
        refreshMatches()
        
        // Set scanning state
        isScanning = true
    }
    
    private func refreshMatches() {
        Task {
            await matchEngine.findMatchesForCurrentUser()
        }
    }
    
    private func toggleScanning() {
        withAnimation(.spring()) {
            isScanning.toggle()
            scanToggle.toggle()
        }
        
        if isScanning {
            refreshMatches()
        }
    }
    
    // MARK: - Computed Properties
    
    private var radarStatusColor: Color {
        if matchEngine.isLoading {
            return .orange
        } else if matchEngine.errorMessage != nil {
            return .red
        } else if isScanning {
            return .green
        } else {
            return .gray
        }
    }
    
    private var radarStatusText: String {
        if matchEngine.isLoading {
            return "Searching"
        } else if let error = matchEngine.errorMessage {
            return "Error"
        } else if isScanning {
            return "Active"
        } else {
            return "Paused"
        }
    }
    
    private var bestMatchPercentage: String {
        if let bestMatch = matchEngine.currentMatches.first {
            return "\(Int(bestMatch.matchPercentage))%"
        } else {
            return "--"
        }
    }
    
    private func generateAIInsight() -> String {
        let matchCount = matchEngine.currentMatches.count
        
        if matchEngine.isLoading {
            return "🔍 Scanning for compatible people nearby using AI analysis..."
        } else if let error = matchEngine.errorMessage {
            return "⚠️ \(error). Please check your location settings and try again."
        } else if matchCount == 0 {
            return "🎯 No matches found yet. Make sure your location is enabled and you're visible to others. Try answering more AI questions to improve matches!"
        } else if let topMatch = matchEngine.currentMatches.first {
            return "🎉 Found \(matchCount) compatible people nearby! \(topMatch.user.firstName) has the highest compatibility at \(Int(topMatch.matchPercentage))% based on your shared interests and AI answers."
        } else {
            return "✨ Keep your radar active to discover new connections as people come and go!"
        }
    }
    
    // Remove the old sampleMatches() and createSampleMatch() methods
}

// MARK: - Supporting Views

struct UserRadarDot: View {
    let match: MatchResult
    var isScanning: Bool = true
    let onTap: () -> Void
    @State private var isPulsing = false
    
    private var dotColor: Color {
        switch match.user.firstName {
        case "M": return .red
        case "A", "J": return .green
        case "S": return .orange
        default: return .cyan
        }
    }
    
    // Helper function to calculate radar position for a user
    private func radarPosition(for user: User) -> CGPoint {
        let hash = abs(user.id.hashValue)
        let x = Double((hash % 200) - 100) // -100 to 100
        let y = Double(((hash / 200) % 200) - 100) // -100 to 100
        return CGPoint(x: x, y: y)
    }
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(dotColor.opacity(0.3))
                    .frame(width: isPulsing ? 32 : 28)
                    .blur(radius: 6)
                
                Circle()
                    .fill(dotColor)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Text(match.user.firstName)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .shadow(color: dotColor, radius: 8)
            }
        }
        .offset(x: radarPosition(for: match.user).x, y: radarPosition(for: match.user).y)
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                isPulsing.toggle()
            }
        }
    }
}

private func getDisplayName(for letter: String) -> String {
    switch letter {
    case "M": return "Maya"
    case "A": return "Alex" 
    case "J": return "Jordan"
    case "S": return "Sam"
    default: return letter
    }
}

struct CustomSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.2))
                    .frame(height: 4)
                
                // Fill
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [.cyan, .green],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)), height: 4)
                
                // Thumb
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 16, height: 16)
                    .shadow(color: .cyan, radius: 4)
                    .offset(x: geometry.size.width * CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)) - 8)
            }
        }
        .frame(height: 16)
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    let percent = gesture.location.x / UIScreen.main.bounds.width * 0.8 // Approximate slider width
                    let newValue = range.lowerBound + (range.upperBound - range.lowerBound) * Double(percent)
                    value = min(max(newValue, range.lowerBound), range.upperBound)
                }
        )
    }
}

struct GlassToggle: View {
    @Binding var isOn: Bool
    
    var body: some View {
        Button(action: { isOn.toggle() }) {
            RoundedRectangle(cornerRadius: 15)
                .fill(isOn ? Color.cyan.opacity(0.8) : Color.white.opacity(0.2))
                .frame(width: 50, height: 30)
                .overlay(
                    Circle()
                        .fill(Color.white)
                        .frame(width: 26, height: 26)
                        .offset(x: isOn ? 10 : -10)
                        .shadow(color: .black.opacity(0.2), radius: 2)
                )
                .animation(.easeInOut(duration: 0.2), value: isOn)
        }
    }
}

struct GlassUserDetailView: View {
    let match: MatchResult
    @Environment(\.dismiss) private var dismiss
    @StateObject private var interactionService = MatchInteractionService.shared
    @EnvironmentObject var chatManager: IcebreakerChatManager
    @State private var showingChatView = false
    @State private var selectedConversation: IcebreakerChatConversation?
    @State private var showingIntroMessageView = false
    @State private var showingSuccessMessage = false
    @State private var successMessage = ""
    
    var body: some View {
        ZStack {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 24) {
                        // User Header
                        GlassCard {
                            VStack(spacing: 16) {
                                // Avatar with match percentage
                                ZStack {
                                    Circle()
                                        .fill(match.matchLevel.color)
                                        .frame(width: 100, height: 100)
                                        .shadow(color: match.matchLevel.color, radius: 20)
                                    
                                    Text(match.user.firstName.prefix(1))
                                        .font(.system(size: 40, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    // Match percentage badge
                                    VStack {
                                        Spacer()
                                        HStack {
                                            Spacer()
                                            MatchPercentageBadge(percentage: match.matchPercentage, size: 30)
                                                .offset(x: 15, y: 15)
                                        }
                                    }
                                    .frame(width: 100, height: 100)
                                }
                                
                                VStack(spacing: 8) {
                                    Text(match.user.firstName)
                                        .font(.title2)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                    
                                    HStack(spacing: 16) {
                                        Text("\(Int(match.matchPercentage))% Match")
                                            .font(.subheadline)
                                            .foregroundColor(match.matchLevel.color)
                                        
                                        Text("•")
                                            .foregroundColor(.white.opacity(0.5))
                                        
                                        Text("\(Int(match.user.distance))m away")
                                            .font(.subheadline)
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    
                                    StatusIndicator(isActive: match.user.isActive)
                                }
                            }
                        }
                        
                        // AI Analysis
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("🧠 AI Connection Analysis")
                                        .font(.headline)
                                        .foregroundColor(.cyan)
                                    
                                    Spacer()
                                    
                                    Text("\(Int(match.matchPercentage))% Match")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(match.matchLevel.color)
                                }
                                
                                Text(match.aiInsight)
                                    .font(.body)
                                    .foregroundColor(.white.opacity(0.9))
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        
                        // Shared Answers
                        if !match.sharedAnswers.isEmpty {
                            GlassCard {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("📝 Shared Experiences")
                                        .font(.headline)
                                        .foregroundColor(.green)
                                    
                                    ForEach(Array(match.sharedAnswers.prefix(2).enumerated()), id: \.offset) { index, sharedAnswer in
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text(sharedAnswer.questionText)
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.6))
                                            
                                            VStack(alignment: .leading, spacing: 6) {
                                                HStack {
                                                    Text("You:")
                                                        .font(.caption)
                                                        .fontWeight(.medium)
                                                        .foregroundColor(.cyan)
                                                    Text(sharedAnswer.userAnswer)
                                                        .font(.caption)
                                                        .foregroundColor(.white)
                                                }
                                                
                                                HStack {
                                                    Text("Them:")
                                                        .font(.caption)
                                                        .fontWeight(.medium)
                                                        .foregroundColor(.green)
                                                    Text(sharedAnswer.matchAnswer)
                                                        .font(.caption)
                                                        .foregroundColor(.white)
                                                }
                                            }
                                            .padding(.vertical, 8)
                                            .padding(.horizontal, 12)
                                            .background(Color.white.opacity(0.05))
                                            .cornerRadius(8)
                                        }
                                        
                                        if index < match.sharedAnswers.count - 1 {
                                            Divider()
                                                .background(Color.white.opacity(0.2))
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Perfect Conversation Starter
                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("💡 Perfect Conversation Starter")
                                    .font(.headline)
                                    .foregroundColor(.green)
                                
                                Text(match.conversationStarter)
                                    .font(.body)
                                    .foregroundColor(.white.opacity(0.9))
                                    .padding()
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.green.opacity(0.3), lineWidth: 1)
                                    )
                            }
                        }
                        
                        // Action Buttons
                        VStack(spacing: 12) {
                            HStack(spacing: 16) {
                                Button("👋 Wave") {
                                    sendWave()
                                }
                                .buttonStyle(GlassButtonStyle(isSecondary: true))
                                .frame(maxWidth: .infinity)
                                
                                Button("💬 Start Chat") {
                                    showingIntroMessageView = true
                                }
                                .buttonStyle(GlassButtonStyle())
                                .frame(maxWidth: .infinity)
                            }
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding()
                }
                .navigationTitle("Profile")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                        .foregroundColor(.white)
                    }
                }
            }
            .sheet(isPresented: $showingIntroMessageView) {
                IntroMessageView(match: match) { message in
                    sendIntroMessage(message)
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
            
            // Success Overlay
            if showingSuccessMessage {
                VStack {
                    Spacer()
                    
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                        
                        Text(successMessage)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.black.opacity(0.9))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 40)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    
                    Spacer()
                        .frame(height: 100)
                }
                .onAppear {
                    // Auto-dismiss after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            showingSuccessMessage = false
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func sendWave() {
        Task {
            let success = await interactionService.sendWave(to: match)
            if success {
                withAnimation {
                    successMessage = "Wave sent to \(match.user.firstName)! 👋"
                    showingSuccessMessage = true
                }
            }
        }
    }
    
    private func sendIntroMessage(_ message: String) {
        Task {
            if let conversation = await interactionService.sendIntroMessage(to: match, message: message) {
                chatManager.updateConversation(conversation)
                selectedConversation = conversation
                
                withAnimation {
                    successMessage = "Intro message sent to \(match.user.firstName)! 📝"
                    showingSuccessMessage = true
                }
                
                // Auto-open chat after a brief delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    showingChatView = true
                }
            }
        }
    }
}

struct MatchPopupView: View {
    let match: MatchResult
    @State private var showingFullProfile = false
    var onDismiss: () -> Void = {}
    
    var body: some View {
        Button(action: {
            showingFullProfile = true
        }) {
            HStack(spacing: 16) {
                // User avatar
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(String(match.user.firstName.prefix(1)).uppercased())
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    )
                
                // User name and match info
                VStack(alignment: .leading, spacing: 4) {
                    Text(match.user.firstName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.cyan)
                    
                    Text("\(Int(match.matchPercentage))% Match")
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.green)
                    
                    Text(match.aiInsight)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Arrow indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.cyan.opacity(0.5), lineWidth: 2)
                )
        )
        .padding(.horizontal, 20)
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
        .sheet(isPresented: $showingFullProfile) {
            GlassUserDetailView(match: match)
        }
    }
}

struct SliderView: View {
    @Binding var visibilityRange: Double
    
    var body: some View {
        HStack {
            // Min label
            Text("5m")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 30, alignment: .leading)
            
            // Slider
            CustomSlider(value: $visibilityRange, range: 5...50)
                .accentColor(.cyan)
            
            // Max label
            Text("50m")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 30, alignment: .trailing)
        }
    }
}

#Preview {
    GlassRadarView()
        .environmentObject(AIQuestionManager())
}
