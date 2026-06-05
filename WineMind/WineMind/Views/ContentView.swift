import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var consentStore: PrivacyConsentStore

    init() {
        // Tab bar appearance — dark
        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(red: 0.07, green: 0.05, blue: 0.06, alpha: 1.0)
        tabAppearance.shadowColor = UIColor(red: 0.22, green: 0.18, blue: 0.20, alpha: 1.0)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        // Nav bar appearance
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(red: 0.07, green: 0.05, blue: 0.06, alpha: 1.0)
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(red: 0.96, green: 0.93, blue: 0.88, alpha: 1.0)
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(red: 0.96, green: 0.93, blue: 0.88, alpha: 1.0),
            .font: UIFont.systemFont(ofSize: 34, weight: .bold)
        ]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
    }

    var body: some View {
        TabView {
            WineListView()
                .tabItem {
                    Label("Cellar", systemImage: "wineglass.fill")
                }

            RecommendationsView()
                .tabItem {
                    Label("Discover", systemImage: "sparkles")
                }

            SettingsView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle.fill")
                }
        }
        .tint(WineTheme.gold)
        .task {
            await WineSyncService.shared.restoreIfNeeded(
                context: modelContext,
                allowsCloudSync: consentStore.consent.allowsCloudSync
            )
        }
    }
}
