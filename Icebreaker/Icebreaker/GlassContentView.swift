import SwiftUI

@main
struct IcebreakerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

struct ContentView: View {
    @StateObject private var authManager = AuthManager()
    @StateObject private var questionManager = AIQuestionManager()
    @StateObject private var chatManager = ChatManager()
    
    var body: some View {
        ZStack {
            // Force the animated background on all views
            AnimatedBackground()
                .ignoresSafeArea()
            
            Group {
                if authManager.isSignedIn {
                    MainTabView()
                } else {
                    GlassWelcomeView()
                }
            }
        }
        .environmentObject(authManager)
        .environmentObject(questionManager)
        .environmentObject(chatManager)
        .preferredColorScheme(.dark)
        .onAppear {
            authManager.loadSavedUser()
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var questionManager: AIQuestionManager
    @EnvironmentObject var chatManager: ChatManager
    
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
            
            // Configure badge appearance
            appearance.stackedLayoutAppearance.normal.badgeBackgroundColor = UIColor.systemRed
            appearance.stackedLayoutAppearance.normal.badgeTextAttributes = [
                .foregroundColor: UIColor.white,
                .font: UIFont.systemFont(ofSize: 12, weight: .medium)
            ]
            
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

#Preview {
    ContentView()
}
