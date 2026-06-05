import SwiftUI
import SwiftData

struct SettingsView: View {
    @EnvironmentObject var auth: AuthService
    @EnvironmentObject var profileStore: TasteProfileStore
    @Query private var wines: [Wine]
    @State private var showingSignOutConfirmation = false
    @State private var showingQuiz = false
    @State private var showingManageData = false

    var body: some View {
        NavigationStack {
            ZStack {
                WineTheme.backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Profile header
                        profileHeader

                        // Stats
                        statsCard

                        // iCloud status
                        cloudKitCard

                        // Taste profile
                        tasteProfileCard

                        // Privacy & data
                        privacyCard

                        // About
                        aboutCard

                        // Sign out
                        Button {
                            showingSignOutConfirmation = true
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                .frame(maxWidth: .infinity)
                                .foregroundStyle(WineTheme.burgundyLight)
                                .padding(.vertical, 14)
                                .background(WineTheme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(WineTheme.burgundy.opacity(0.4), lineWidth: 1)
                                }
                        }
                        .padding(.horizontal)

                        Spacer().frame(height: 20)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Profile")
            .fullScreenCover(isPresented: $showingQuiz) {
                TasteQuizView()
                    .environmentObject(profileStore)
            }
            .sheet(isPresented: $showingManageData) {
                ManageDataView()
            }
            .confirmationDialog("Sign out of WineMind?", isPresented: $showingSignOutConfirmation) {
                Button("Sign Out", role: .destructive) { auth.signOut() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your wines will remain synced via iCloud and restored next time you sign in.")
            }
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(WineTheme.burgundyGradient)
                    .frame(width: 88, height: 88)
                    .shadow(color: WineTheme.burgundy.opacity(0.5), radius: 16)
                Text(initials)
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .foregroundStyle(WineTheme.champagne)
            }

            Text(auth.userName ?? "Wine Enthusiast")
                .font(.wineTitle2)
                .foregroundStyle(WineTheme.cream)

            if let email = auth.userEmail {
                Text(email)
                    .font(.wineCaption)
                    .foregroundStyle(WineTheme.mutedText)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Your Cellar Stats")

            HStack(spacing: 12) {
                StatTile(value: "\(wines.count)", label: "Wines")
                StatTile(value: String(format: "%.1f", averageScore), label: "Avg Score")
                StatTile(value: "\(highRatedCount)", label: "Favorites")
            }

            if let topVariety = topVariety {
                HStack {
                    Image(systemName: "leaf.fill")
                        .foregroundStyle(WineTheme.gold)
                    Text("Favorite grape:")
                        .foregroundStyle(WineTheme.mutedText)
                    Text(topVariety)
                        .foregroundStyle(WineTheme.cream)
                        .italic()
                    Spacer()
                }
                .font(.wineCallout)
                .padding(.top, 4)
            }
        }
        .padding()
        .background(WineTheme.cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private var cloudKitCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Sync & Privacy")

            HStack(spacing: 12) {
                Image(systemName: cloudKitIcon)
                    .font(.title2)
                    .foregroundStyle(cloudKitColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(auth.cloudKitStatusMessage)
                        .font(.wineBody)
                        .foregroundStyle(WineTheme.cream)
                    Text("Wine collection syncs across your devices")
                        .font(.wineCaption)
                        .foregroundStyle(WineTheme.mutedText)
                }
                Spacer()
            }
            .padding()
            .background(WineTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            HStack(spacing: 12) {
                Image(systemName: "person.3.fill")
                    .font(.title2)
                    .foregroundStyle(WineTheme.gold)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Anonymous community recommendations")
                        .font(.wineBody)
                        .foregroundStyle(WineTheme.cream)
                    Text("Your ratings power picks for everyone, anonymously")
                        .font(.wineCaption)
                        .foregroundStyle(WineTheme.mutedText)
                }
                Spacer()
            }
            .padding()
            .background(WineTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .padding()
        .background(WineTheme.cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private var tasteProfileCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Taste Profile")

            let profile = profileStore.profile
            VStack(spacing: 8) {
                if !profile.preferredColors.isEmpty {
                    HStack {
                        Image(systemName: "wineglass.fill").foregroundStyle(WineTheme.gold).frame(width: 24)
                        Text("Enjoys")
                            .foregroundStyle(WineTheme.mutedText)
                        Text(profile.preferredColors.map { $0.rawValue }.joined(separator: ", "))
                            .foregroundStyle(WineTheme.cream).italic()
                        Spacer()
                    }
                    .font(.wineCallout)
                }
                if let body = profile.preferredBody {
                    HStack {
                        Image(systemName: "scalemass.fill").foregroundStyle(WineTheme.gold).frame(width: 24)
                        Text("Body")
                            .foregroundStyle(WineTheme.mutedText)
                        Text(body.rawValue)
                            .foregroundStyle(WineTheme.cream).italic()
                        Spacer()
                    }
                    .font(.wineCallout)
                }
                if !profile.preferredVarieties.isEmpty {
                    HStack(alignment: .top) {
                        Image(systemName: "leaf.fill").foregroundStyle(WineTheme.gold).frame(width: 24)
                        Text("Favorites")
                            .foregroundStyle(WineTheme.mutedText)
                        Text(profile.preferredVarieties.sorted().joined(separator: ", "))
                            .foregroundStyle(WineTheme.cream).italic()
                        Spacer()
                    }
                    .font(.wineCallout)
                }
            }
            .padding(.vertical, 4)

            Button {
                showingQuiz = true
            } label: {
                Label("Retake Taste Quiz", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(WineTheme.gold)
                    .background(WineTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(WineTheme.gold.opacity(0.4), lineWidth: 0.5)
                    }
            }
        }
        .padding()
        .background(WineTheme.cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private var privacyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Privacy & Data")

            Button {
                showingManageData = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "lock.shield.fill")
                        .font(.title3)
                        .foregroundStyle(WineTheme.gold)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Manage Your Data")
                            .font(.wineBody.weight(.semibold))
                            .foregroundStyle(WineTheme.cream)
                        Text("Permissions, export, delete account")
                            .font(.wineCaption)
                            .foregroundStyle(WineTheme.mutedText)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(WineTheme.dimText)
                }
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(WineTheme.cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("About")

            InfoRow(label: "Version", value: "1.0.0")
            InfoRow(label: "Wine Recognition", value: "Apple Vision")
            InfoRow(label: "Recommendations", value: "Apple NL + CloudKit")
        }
        .padding()
        .background(WineTheme.cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private func sectionTitle(_ text: String) -> some View {
        HStack {
            Text(text.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(2)
                .foregroundStyle(WineTheme.gold)
            Rectangle()
                .fill(WineTheme.gold.opacity(0.3))
                .frame(height: 0.5)
        }
    }

    // MARK: - Computed

    private var initials: String {
        let name = auth.userName ?? "Wine Enthusiast"
        let parts = name.split(separator: " ")
        let chars = parts.compactMap { $0.first }.prefix(2)
        return String(chars).uppercased()
    }

    private var averageScore: Double {
        guard !wines.isEmpty else { return 0 }
        return wines.reduce(0.0) { $0 + $1.score } / Double(wines.count)
    }

    private var highRatedCount: Int {
        wines.filter { $0.score >= 8.0 }.count
    }

    private var topVariety: String? {
        Dictionary(grouping: wines.filter { !$0.variety.isEmpty && $0.score >= 7.0 }, by: { $0.variety })
            .max(by: { $0.value.count < $1.value.count })?.key
    }

    private var cloudKitIcon: String {
        switch auth.cloudKitStatus {
        case .available: return "checkmark.icloud.fill"
        case .noAccount: return "icloud.slash"
        default: return "icloud"
        }
    }

    private var cloudKitColor: Color {
        switch auth.cloudKitStatus {
        case .available: return WineTheme.gold
        case .noAccount, .restricted: return WineTheme.burgundyLight
        default: return WineTheme.mutedText
        }
    }
}

struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(WineTheme.gold)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .medium))
                .tracking(1.5)
                .foregroundStyle(WineTheme.mutedText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(WineTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.wineBody)
                .foregroundStyle(WineTheme.mutedText)
            Spacer()
            Text(value)
                .font(.wineBody.weight(.semibold))
                .foregroundStyle(WineTheme.cream)
        }
        .padding(.vertical, 4)
    }
}
