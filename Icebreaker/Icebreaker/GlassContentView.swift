import SwiftUI
import CoreLocation
import UserNotifications
import Firebase

@main
struct IcebreakerApp: App {
    
    init() {
        // Initialize Firebase
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

struct ContentView: View {
    @StateObject private var authManager = FirebaseAuthManager()
    @StateObject private var questionManager = AIQuestionManager()
    @StateObject private var chatManager = IcebreakerChatManager.shared
    @StateObject private var realTimeChatManager = RealTimeChatManager.shared
    @StateObject private var locationManager = LocationManager()
    @StateObject private var matchEngine = MatchEngine.shared
    
    var body: some View {
        ZStack {
            AnimatedBackground()
                .ignoresSafeArea()
            
            Group {
                if authManager.isSignedIn && authManager.hasCompletedOnboarding {
                    MainTabView()
                } else {
                    OnboardingFlow()
                }
            }
        }
        .environmentObject(authManager)
        .environmentObject(questionManager)
        .environmentObject(chatManager)
        .environmentObject(realTimeChatManager)
        .environmentObject(locationManager)
        .environmentObject(matchEngine)
        .preferredColorScheme(.dark)
        .onAppear {
            // Connect LocationManager with FirebaseAuthManager
            locationManager.setAuthManager(authManager)
        }
    }
}

// MARK: - Production Onboarding Flow

struct OnboardingFlow: View {
    @EnvironmentObject var authManager: FirebaseAuthManager
    @State private var currentStep = 0
    @State private var email = ""
    @State private var password = ""
    @State private var firstName = ""
    @State private var showSignIn = false
    
    var body: some View {
        NavigationStack {
            switch currentStep {
            case 0: WelcomeScreen()
            case 1: SignUpScreen()
            case 2: LocationPermissionScreen(currentStep: $currentStep)
            case 3: NotificationPermissionScreen(currentStep: $currentStep)
            default: WelcomeScreen()
            }
        }
        .sheet(isPresented: $showSignIn) {
            SignInView()
        }
    }
    
    // MARK: - Welcome Screen
    private func WelcomeScreen() -> some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 20) {
                Text("🧊")
                    .font(.system(size: 80))
                
                Text("Icebreaker")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("AI-powered connections with people nearby")
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                Button("Get Started") {
                    withAnimation {
                        currentStep = 1
                    }
                }
                .buttonStyle(GlassButtonStyle())
                
                Button("Already have an account? Sign In") {
                    showSignIn = true
                }
                .foregroundColor(.cyan)
                .font(.subheadline)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 50)
        }
    }
    
    // MARK: - Sign Up Screen
    private func SignUpScreen() -> some View {
        VStack(spacing: 30) {
            VStack(spacing: 12) {
                Text("Create Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Let's get you started on Icebreaker")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.top, 60)
            
            VStack(spacing: 20) {
                ModernTextField(text: $firstName, placeholder: "First Name", icon: "person")
                ModernTextField(text: $email, placeholder: "Email", icon: "envelope")
                ModernTextField(text: $password, placeholder: "Password", icon: "lock", isSecure: true)
            }
            .padding(.horizontal, 20)
            
            if !authManager.errorMessage.isEmpty {
                Text(authManager.errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
                    .padding(.horizontal, 20)
            }
            
            Spacer()
            
            VStack(spacing: 16) {
                Button(authManager.isLoading ? "Creating Account..." : "Continue") {
                    signUp()
                }
                .buttonStyle(GlassButtonStyle())
                .disabled(firstName.isEmpty || email.isEmpty || password.isEmpty || authManager.isLoading)
                .padding(.horizontal, 20)
                
                Button("Back") {
                    withAnimation {
                        currentStep = 0
                    }
                }
                .foregroundColor(.cyan)
            }
            .padding(.bottom, 50)
        }
    }
    
    private func signUp() {
        authManager.signUp(email: email, password: password, firstName: firstName) { success in
            if success {
                withAnimation {
                    currentStep = 2
                }
            }
        }
    }
}

// MARK: - Permission Screens

struct LocationPermissionScreen: View {
    @EnvironmentObject var authManager: FirebaseAuthManager
    @EnvironmentObject var locationManager: LocationManager
    @Binding var currentStep: Int
    
    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 20) {
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.cyan)
                
                Text("Enable Location")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Icebreaker uses your location to find people nearby. Your exact location is never shared - only approximate distance.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            VStack(spacing: 16) {
                Button("Enable Location") {
                    locationManager.requestLocationPermission()
                    // Navigate to next step
                    withAnimation {
                        currentStep = 3
                    }
                }
                .buttonStyle(GlassButtonStyle())
                .padding(.horizontal, 20)
                
                Button("Skip for now") {
                    // Navigate to next step
                    withAnimation {
                        currentStep = 3
                    }
                }
                .foregroundColor(.cyan)
            }
            .padding(.bottom, 50)
        }
    }
}

struct NotificationPermissionScreen: View {
    @EnvironmentObject var authManager: FirebaseAuthManager
    @Binding var currentStep: Int
    
    var body: some View {
        VStack(spacing: 40) {
            VStack(spacing: 20) {
                Image(systemName: "bell.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.cyan)
                
                Text("Stay Connected")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Get notified when you have new matches or messages. You can always change this later in Settings.")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            VStack(spacing: 16) {
                Button("Enable Notifications") {
                    requestNotificationPermission()
                    completeOnboarding()
                }
                .buttonStyle(GlassButtonStyle())
                .padding(.horizontal, 20)
                
                Button("Skip for now") {
                    completeOnboarding()
                }
                .foregroundColor(.cyan)
            }
            .padding(.bottom, 50)
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                print("Notification permission granted: \(granted)")
            }
        }
    }
    
    private func completeOnboarding() {
        authManager.completeOnboarding()
    }
}

// MARK: - Sign In View

struct SignInView: View {
    @EnvironmentObject var authManager: FirebaseAuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedBackground()
                    .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    VStack(spacing: 12) {
                        Text("Welcome Back")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("Sign in to your Icebreaker account")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.top, 60)
                    
                    VStack(spacing: 20) {
                        ModernTextField(text: $email, placeholder: "Email", icon: "envelope")
                        ModernTextField(text: $password, placeholder: "Password", icon: "lock", isSecure: true)
                    }
                    .padding(.horizontal, 20)
                    
                    if !authManager.errorMessage.isEmpty {
                        Text(authManager.errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .padding(.horizontal, 20)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 16) {
                        Button(authManager.isLoading ? "Signing In..." : "Sign In") {
                            signIn()
                        }
                        .buttonStyle(GlassButtonStyle())
                        .disabled(email.isEmpty || password.isEmpty || authManager.isLoading)
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 50)
                }
            }
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.cyan)
                }
            }
        }
    }
    
    private func signIn() {
        authManager.signIn(email: email, password: password) { success in
            if success {
                dismiss()
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var questionManager: AIQuestionManager
    @EnvironmentObject var chatManager: IcebreakerChatManager
    
    var body: some View {
        TabView {
            // Remove individual AnimatedBackground from each view since it's now global
            GlassRadarView()
                .tabItem {
                    Image(systemName: "dot.radiowaves.left.and.right")
                    Text("Radar")
                }
            
            GlassMatchListView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Matches")
                }
            
            GlassChatListView()
                .tabItem {
                    Image(systemName: "message")
                    Text("Chat")
                }
                .badge(chatManager.totalUnreadCount > 0 ? "\(chatManager.totalUnreadCount)" : nil)
            
            GlassAIQuestionView()
                .tabItem {
                    Image(systemName: "brain.head.profile")
                    Text("Questions")
                }
                .badge(questionManager.hasPendingQuestion ? "!" : nil)
            
            GlassSettingsView()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("Settings")
                }
        }
        .accentColor(.cyan)
        .preferredColorScheme(.dark)
        .onAppear {
            // Ensure proper tab bar styling to prevent overlap
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.black.withAlphaComponent(0.8)
            
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

#Preview {
    ContentView()
}
