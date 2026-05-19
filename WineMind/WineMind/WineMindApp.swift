import SwiftUI
import SwiftData

@main
struct WineMindApp: App {
    @StateObject private var auth = AuthService.shared
    @StateObject private var recommender = CollaborativeRecommender.shared
    @StateObject private var profileStore = TasteProfileStore.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if !auth.isSignedIn {
                    SignInView()
                        .environmentObject(auth)
                } else if !profileStore.hasCompletedQuiz {
                    TasteQuizView()
                        .environmentObject(profileStore)
                } else {
                    ContentView()
                        .environmentObject(auth)
                        .environmentObject(recommender)
                        .environmentObject(profileStore)
                }
            }
            .preferredColorScheme(.dark)
        }
        .modelContainer(for: Wine.self)
    }
}
