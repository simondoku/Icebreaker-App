import SwiftUI
import CoreLocation

struct GlassRadarView: View {
    @EnvironmentObject var locationManager: LocationManager
    @StateObject private var matchEngine = MatchEngine()
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
                locationManager.requestLocationPermission()
                updateMatches()
                isScanning = true
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
                            .fill(isScanning ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: isScanning)
                        
                        Text("AI Radar • \(isScanning ? "Scanning" : "Paused")")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring()) {
                        isScanning.toggle()
                        scanToggle.toggle()
                    }
                }) {
                    Image(systemName: isScanning ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.cyan)
                }
            }
            
            // Stats bar
            HStack(spacing: 20) {
                StatItem(number: "4", label: "Nearby")
                StatItem(number: "89%", label: "Best Match")
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
                VStack {
                    MatchPopupView(match: match)
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
        ForEach(sampleMatches(), id: \.user.id) { match in
            UserRadarDot(
                match: match,
                isScanning: isScanning,
                onTap: {
                    selectedUserForPopup = match
                    withAnimation(.spring()) {
                        showingMatchPopup = true
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        withAnimation(.easeOut) {
                            showingMatchPopup = false
                        }
                    }
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
            }
            
            Text("Found 4 people nearby with shared experiences from your recent answers. Alex has the highest compatibility based on reading habits and daily routines.")
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
    
    // MARK: - Helper Methods
    
    private func sampleMatches() -> [MatchResult] {
        let matches = [
            createSampleMatch(letter: "A", color: .green, position: CGPoint(x: 45, y: -30), matchPercent: 89, summary: "Both love morning coffee routines"),
            createSampleMatch(letter: "M", color: .red, position: CGPoint(x: -65, y: -50), matchPercent: 67, summary: "Both interested in fitness and healthy living"),
            createSampleMatch(letter: "J", color: .green, position: CGPoint(x: 75, y: 40), matchPercent: 82, summary: "Both enjoy weekend hiking and nature photography"),
            createSampleMatch(letter: "S", color: .orange, position: CGPoint(x: -30, y: 70), matchPercent: 74, summary: "Both passionate about sustainable living")
        ]
        return matches
    }
    
    private func updateMatches() {
        matchEngine.findMatches(userAnswers: questionManager.userAnswers)
    }
    
    private func createSampleMatch(letter: String, color: Color, position: CGPoint, matchPercent: Int = 85, summary: String = "Sample insight") -> MatchResult {
        let user = User(
            id: UUID().uuidString,
            firstName: getDisplayName(for: letter),
            age: 28,
            bio: summary,
            location: "San Francisco",
            interests: ["fitness", "coffee", "hiking"]
        )
        
        var updatedUser = user
        updatedUser.latitude = 37.7749
        updatedUser.longitude = -122.4194
        updatedUser.distanceFromUser = 15.0
        updatedUser.isOnline = true
        updatedUser.lastSeen = Date()
        updatedUser.isVisible = true
        updatedUser.firstName = letter
        
        return MatchResult(
            user: updatedUser,
            compatibilityScore: Double(matchPercent) / 100.0,
            sharedAnswers: [],
            aiInsight: summary,
            distance: 15.0
        )
    }
    
    // Helper function to calculate radar position for a user
    private func radarPosition(for user: User) -> CGPoint {
        let hash = abs(user.id.hashValue)
        let x = Double((hash % 200) - 100) // -100 to 100
        let y = Double(((hash / 200) % 200) - 100) // -100 to 100
        return CGPoint(x: x, y: y)
    }
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
                                    dismiss()
                                }
                                .buttonStyle(GlassButtonStyle(isSecondary: true))
                                .frame(maxWidth: .infinity)
                                
                                Button("💬 Start Chat") {
                                    dismiss()
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
        }
    }
}

struct MatchPopupView: View {
    let match: MatchResult
    
    var body: some View {
        HStack(spacing: 16) {
            // User name and match info
            VStack(alignment: .leading, spacing: 4) {
                Text(getDisplayName(for: match.user.firstName))
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
        }
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
