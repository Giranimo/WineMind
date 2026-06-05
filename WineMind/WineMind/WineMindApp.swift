import SwiftUI
import SwiftData

@main
struct WineMindApp: App {
    @StateObject private var auth = AuthService.shared
    @StateObject private var recommender = CollaborativeRecommender.shared
    @StateObject private var profileStore = TasteProfileStore.shared
    @StateObject private var consentStore = PrivacyConsentStore.shared

    /// Local-only SwiftData store. SwiftData's automatic CloudKit mirroring is
    /// deliberately disabled: all CloudKit sync is handled separately and
    /// consent-gated by CloudKitService/WineSyncService. Letting SwiftData
    /// auto-mirror would (a) sync wines to iCloud regardless of consent and
    /// (b) crash at launch, since the Wine model isn't CloudKit-schema-compatible
    /// (non-optional properties without defaults).
    private let modelContainer: ModelContainer

    init() {
        do {
            let config = ModelConfiguration(cloudKitDatabase: .none)
            modelContainer = try ModelContainer(for: Wine.self, configurations: config)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !auth.isSignedIn {
                    SignInView()
                        .environmentObject(auth)
                } else if consentStore.consent.needsReConsent {
                    PrivacyConsentView()
                        .environmentObject(consentStore)
                } else if !profileStore.hasCompletedQuiz {
                    TasteQuizView()
                        .environmentObject(profileStore)
                } else {
                    ContentView()
                        .environmentObject(auth)
                        .environmentObject(recommender)
                        .environmentObject(profileStore)
                        .environmentObject(consentStore)
                }
            }
            .preferredColorScheme(.dark)
        }
        .modelContainer(modelContainer)
    }
}
