import SwiftUI

struct GlassSettingsView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var questionManager: AIQuestionManager
    @StateObject private var locationManager = LocationManager()
    
    @State private var showingDeleteConfirmation = false
    @State private var showingSignOutConfirmation = false
    @State private var showingAnswerHistory = false
    
    var body: some View {
            
            NavigationStack {
                ScrollView {
                    VStack(spacing: 20) {
                        // Profile Section
                        if let user = authManager.currentUser {
                            GlassProfileSection(user: user)
                        }
                        
                        // AI Questions Section
                        GlassSettingsSection(title: "🧠 AI Questions") {
                            GlassAIQuestionSettings()
                        }
                        
                        // Discovery & Privacy Section
                        GlassSettingsSection(title: "📍 Discovery & Privacy") {
                            GlassDiscoverySettings(locationManager: locationManager)
                        }
                        
                        // Account Section
                        GlassSettingsSection(title: "⚙️ Account") {
                            GlassAccountSettings(
                                showingSignOutConfirmation: $showingSignOutConfirmation,
                                showingDeleteConfirmation: $showingDeleteConfirmation
                            )
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding()
                }
                .navigationTitle("Settings")
            }
        .sheet(isPresented: $showingAnswerHistory) {
            GlassAnswerHistoryView()
                .environmentObject(questionManager)
        }
        .alert("Sign Out", isPresented: $showingSignOutConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                authManager.signOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Delete Account", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                authManager.signOut()
            }
        } message: {
            Text("This will permanently delete your account and all data. This action cannot be undone.")
        }
    }
}

struct GlassProfileSection: View {
    let user: User
    
    var body: some View {
        GlassCard {
            HStack(spacing: 15) {
                Circle()
                    .fill(LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Text(user.firstName.prefix(1))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                    )
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(user.firstName)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text("Age \(user.age)")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    
                    if !user.bio.isEmpty {
                        Text(user.bio)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                Button("Edit") {
                    // Handle edit profile
                }
                .buttonStyle(GlassButtonStyle(isSecondary: true))
            }
        }
    }
}

struct GlassSettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 4)
            
            GlassCard {
                content
            }
        }
    }
}

struct GlassAIQuestionSettings: View {
    @State private var dailyQuestionsEnabled = true
    @State private var questionReminders = true
    @State private var shareAIInsights = true
    
    var body: some View {
        VStack(spacing: 16) {
            GlassSettingsRow(
                title: "Daily AI Questions",
                subtitle: "Receive personalized questions to improve matches",
                isOn: $dailyQuestionsEnabled
            )
            
            Divider().background(Color.white.opacity(0.2))
            
            GlassSettingsRow(
                title: "Question Reminders",
                subtitle: "Get gentle nudges to answer pending questions",
                isOn: $questionReminders
            )
            
            Divider().background(Color.white.opacity(0.2))
            
            GlassSettingsRow(
                title: "Share AI Insights",
                subtitle: "Let others see why you matched in their profile",
                isOn: $shareAIInsights
            )
        }
    }
}

struct GlassDiscoverySettings: View {
    let locationManager: LocationManager
    @State private var showRecentAnswers = true
    @State private var autoExpireVisibility = true
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Make me discoverable")
                        .font(.body)
                        .foregroundColor(.white)
                    Text("Allow others to see you when nearby")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                GlassToggle(isOn: Binding(
                    get: { locationManager.isVisible },
                    set: { _ in locationManager.toggleVisibility() }
                ))
            }
            
            Divider().background(Color.white.opacity(0.2))
            
            GlassSettingsRow(
                title: "Show Recent Answers",
                subtitle: "Display your latest responses in your profile",
                isOn: $showRecentAnswers
            )
            
            Divider().background(Color.white.opacity(0.2))
            
            GlassSettingsRow(
                title: "Auto-expire Visibility",
                subtitle: "Hide after 30 minutes of inactivity",
                isOn: $autoExpireVisibility
            )
        }
    }
}

struct GlassAccountSettings: View {
    @Binding var showingSignOutConfirmation: Bool
    @Binding var showingDeleteConfirmation: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            Button(action: { showingSignOutConfirmation = true }) {
                HStack {
                    Text("Sign Out")
                        .font(.body)
                        .foregroundColor(.cyan)
                    Spacer()
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.cyan)
                }
            }
            
            Divider().background(Color.white.opacity(0.2))
            
            Button(action: { showingDeleteConfirmation = true }) {
                HStack {
                    Text("Delete Account")
                        .font(.body)
                        .foregroundColor(.red)
                    Spacer()
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
    }
}

struct GlassSettingsRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            Spacer()
            GlassToggle(isOn: $isOn)
        }
    }
}

#Preview {
    GlassSettingsView()
        .environmentObject(AuthManager())
        .environmentObject(AIQuestionManager())
}
