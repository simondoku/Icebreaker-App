import SwiftUI

struct GlassWelcomeView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showingSignUp = false
    
    var body: some View {
        ZStack {
            VStack(spacing: 40) {
                Spacer()
                
                // App Icon with Glass Effect
                VStack(spacing: 20) {
                    ZStack {
                        // Outer glow
                        Circle()
                            .fill(Color.cyan.opacity(0.3))
                            .frame(width: 140, height: 140)
                            .blur(radius: 20)
                        
                        // Main icon
                        RoundedRectangle(cornerRadius: 30)
                            .fill(
                                LinearGradient(
                                    colors: [Color.cyan, Color.blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .overlay(
                                Text("🎯")
                                    .font(.system(size: 60))
                            )
                            .glassMorphism(intensity: 0.2, cornerRadius: 30)
                            .shadow(color: .cyan.opacity(0.5), radius: 20)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Icebreaker")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("AI finds your perfect conversations")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                }
                
                // Features with Glass Cards
                VStack(spacing: 16) {
                    FeatureGlassCard(
                        icon: "🧠",
                        title: "Smart Questions",
                        description: "AI asks you thoughtful questions daily"
                    )
                    
                    FeatureGlassCard(
                        icon: "🎯",
                        title: "Authentic Matches",
                        description: "Connect based on real moments & thoughts"
                    )
                    
                    FeatureGlassCard(
                        icon: "📍",
                        title: "Nearby & Now",
                        description: "Meet people around you in real-time"
                    )
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Glass Buttons
                VStack(spacing: 16) {
                    Button("Start Your Journey") {
                        showingSignUp = true
                    }
                    .buttonStyle(GlassButtonStyle())
                    .frame(maxWidth: .infinity)
                    
                    Button("I already have an account") {
                        // Demo account
                        authManager.signUp(firstName: "Demo User", age: 25, bio: "Just testing!")
                    }
                    .buttonStyle(GlassButtonStyle(isSecondary: true))
                    .frame(maxWidth: .infinity)
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showingSignUp) {
            GlassSignUpView()
        }
    }
}

struct FeatureGlassCard: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon container
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.cyan.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Text(icon)
                    .font(.system(size: 24))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding()
        .glassMorphism(intensity: 0.05, cornerRadius: 16)
    }
}

struct GlassSignUpView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var firstName = ""
    @State private var age = ""
    @State private var bio = ""
    @State private var selectedInterests: Set<String> = []
    
    private let interests = ["☕ Coffee", "📸 Photography", "🎵 Music", "🏃 Fitness", "📚 Books", "🎨 Art", "🍕 Food", "✈️ Travel", "🎮 Gaming"]
    
    var body: some View {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Text("Create Profile")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Tell us about yourself")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(.top)
                        
                        // Photo Upload
                        GlassCard {
                            VStack(spacing: 12) {
                                Circle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        Text("📷")
                                            .font(.system(size: 40))
                                            .foregroundColor(.white.opacity(0.5))
                                    )
                                
                                Text("Tap to add photo")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                        
                        // Form Fields
                        VStack(spacing: 16) {
                            TextField("First Name", text: $firstName)
                                .textFieldStyle(GlassTextFieldStyle())
                            
                            TextField("Age", text: $age)
                                .textFieldStyle(GlassTextFieldStyle())
                                .keyboardType(.numberPad)
                            
                            TextField("Bio (Optional)", text: $bio, axis: .vertical)
                                .textFieldStyle(GlassTextFieldStyle())
                                .lineLimit(3)
                        }
                        
                        // Interests Selection
                        GlassCard {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Interests")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                                    ForEach(interests, id: \.self) { interest in
                                        InterestTag(
                                            text: interest,
                                            isSelected: selectedInterests.contains(interest)
                                        ) {
                                            if selectedInterests.contains(interest) {
                                                selectedInterests.remove(interest)
                                            } else {
                                                selectedInterests.insert(interest)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        
                        Spacer(minLength: 100)
                    }
                    .padding()
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(.white)
                    }
                }
                .overlay(
                    // Fixed Continue Button
                    VStack {
                        Spacer()
                        Button("Continue") {
                            createAccount()
                        }
                        .buttonStyle(GlassButtonStyle())
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [Color.clear, Color.black.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .disabled(!canContinue)
                        .opacity(canContinue ? 1.0 : 0.6)
                    }
                )
            }
    }
    
    private var canContinue: Bool {
        !firstName.isEmpty && !age.isEmpty && Int(age) != nil
    }
    
    private func createAccount() {
        guard let ageInt = Int(age) else { return }
        
        authManager.signUp(
            firstName: firstName,
            age: ageInt,
            bio: bio.isEmpty ? "Hello! I'm new to Icebreaker." : bio
        )
        
        dismiss()
    }
}

struct InterestTag: View {
    let text: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            Text(text)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .cyan : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isSelected ? Color.cyan.opacity(0.3) : Color.white.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSelected ? Color.cyan : Color.white.opacity(0.2), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    GlassWelcomeView()
        .environmentObject(AuthManager())
}
