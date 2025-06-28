import SwiftUI
import CoreLocation

struct GlassSettingsView: View {
    @EnvironmentObject var authManager: FirebaseAuthManager
    @State private var showingEditProfile = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Settings")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Customize your Icebreaker experience")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 20)
                    
                    // User Profile Section
                    if let user = authManager.userProfile {
                        GlassCard {
                            VStack(spacing: 16) {
                                // Avatar
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue, .cyan],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Text(user.firstName.prefix(1))
                                            .font(.system(size: 32, weight: .bold))
                                            .foregroundColor(.white)
                                    )
                                
                                VStack(spacing: 4) {
                                    Text(user.firstName)
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                    
                                    Text(user.email)
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.7))
                                    
                                    Text("Member since \(user.createdAt.formatted(.dateTime.month().day().year()))")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                
                                Button("Edit Profile") {
                                    showingEditProfile = true
                                }
                                .buttonStyle(GlassButtonStyle())
                            }
                        }
                    }
                    
                    // Privacy & Discovery
                    GlassCard {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Privacy & Discovery")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            SettingsToggle(
                                title: "Make me discoverable",
                                subtitle: "Allow others to find you on the radar",
                                isOn: Binding(
                                    get: { authManager.userProfile?.isVisible ?? false },
                                    set: { authManager.updateVisibility(isVisible: $0) }
                                )
                            )
                            
                            if let userProfile = authManager.userProfile {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Visibility Range: \(Int(userProfile.visibilityRange))m")
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                    
                                    Slider(
                                        value: Binding(
                                            get: { userProfile.visibilityRange },
                                            set: { authManager.updateVisibilityRange($0) }
                                        ),
                                        in: 5...50,
                                        step: 5
                                    )
                                    .accentColor(.cyan)
                                }
                            }
                        }
                    }
                    
                    // AI Questions Settings
                    GlassCard {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("AI Questions")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            SettingsToggle(
                                title: "Daily AI Questions",
                                subtitle: "Get personalized questions to improve matches",
                                isOn: .constant(true)
                            )
                            
                            SettingsToggle(
                                title: "Question Reminders",
                                subtitle: "Notifications when new questions are available",
                                isOn: .constant(false)
                            )
                            
                            SettingsToggle(
                                title: "Share AI Insights",
                                subtitle: "Help others discover compatibility",
                                isOn: .constant(true)
                            )
                        }
                    }
                    
                    // AI Chat Settings
                    GlassCard {
                        VStack(alignment: .leading, spacing: 20) {
                            Text("AI Chat Assistant")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            SettingsToggle(
                                title: "AI Chat Suggestions",
                                subtitle: "Get contextual message suggestions during chats",
                                isOn: Binding(
                                    get: { UserDefaults.standard.bool(forKey: "ai_suggestions_enabled") },
                                    set: { UserDefaults.standard.set($0, forKey: "ai_suggestions_enabled") }
                                )
                            )
                            
                            SettingsToggle(
                                title: "Smart Suggestion Timing",
                                subtitle: "AI suggests messages at natural conversation pauses",
                                isOn: Binding(
                                    get: { UserDefaults.standard.bool(forKey: "smart_suggestion_timing") },
                                    set: { UserDefaults.standard.set($0, forKey: "smart_suggestion_timing") }
                                )
                            )
                        }
                    }
                    
                    // Account Actions
                    GlassCard {
                        VStack(spacing: 16) {
                            Button("Sign Out") {
                                authManager.signOut()
                            }
                            .buttonStyle(GlassButtonStyle())
                            .foregroundColor(.red)
                        }
                    }
                    
                    // Debug Section (only in debug builds)
                    #if DEBUG
                    NavigationLink(destination: AIDebugView()) {
                        HStack {
                            Image(systemName: "ladybug.fill")
                                .foregroundColor(.orange)
                                .font(.title2)
                                .frame(width: 40)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("AI Debug Console")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                Text("Test AI integration and responses")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.white.opacity(0.3))
                                .font(.caption)
                        }
                        .padding()
                        .glassMorphism(intensity: 0.05, cornerRadius: 16)
                    }
                    #endif
                    
                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 20)
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView()
        }
    }
}

struct SettingsToggle: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .toggleStyle(SwitchToggleStyle(tint: .cyan))
        }
    }
}

struct EditProfileView: View {
    @EnvironmentObject var authManager: FirebaseAuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var firstName: String = ""
    @State private var bio: String = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedBackground()
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    VStack(spacing: 12) {
                        Text("Edit Profile")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Update your profile information")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 60)
                    
                    VStack(spacing: 20) {
                        ModernTextField(text: $firstName, placeholder: "First Name", icon: "person")
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 16) {
                                Image(systemName: "text.alignleft")
                                    .foregroundColor(.cyan)
                                    .frame(width: 20)
                                
                                Text("Bio")
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            TextField("Tell others about yourself...", text: $bio, axis: .vertical)
                                .foregroundColor(.white)
                                .padding(.leading, 36)
                                .lineLimit(3...6)
                        }
                        .padding(20)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Button("Save Changes") {
                            authManager.updateProfile(firstName: firstName.isEmpty ? nil : firstName, bio: bio.isEmpty ? nil : bio)
                            dismiss()
                        }
                        .buttonStyle(GlassButtonStyle())
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 50)
                }
            }
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.cyan)
                }
            }
        }
        .onAppear {
            if let userProfile = authManager.userProfile {
                firstName = userProfile.firstName
                bio = userProfile.bio
            }
        }
    }
}

#Preview {
    GlassSettingsView()
        .environmentObject(FirebaseAuthManager())
}
