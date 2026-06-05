import SwiftUI

/// First-launch GDPR consent screen.
/// Each permission is granular and independently togglable — the user can use the app
/// with all of them off (purely offline, no sync, no community).
struct PrivacyConsentView: View {
    @EnvironmentObject var consentStore: PrivacyConsentStore

    @State private var allowsCloudSync: Bool = true
    @State private var allowsAnonymousContribution: Bool = true
    @State private var allowsCommunityRecs: Bool = true
    @State private var showingPolicy = false

    var body: some View {
        ZStack {
            WineTheme.backgroundGradient.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    GoldDivider().padding(.horizontal, 40)

                    intro

                    permissionsSection

                    policyLink

                    Spacer().frame(height: 80)
                }
                .padding(.horizontal, 20)
                .padding(.top, 40)
            }

            VStack {
                Spacer()
                acceptButton
            }
        }
        .sheet(isPresented: $showingPolicy) {
            PrivacyPolicyView()
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 56))
                .foregroundStyle(WineTheme.gold)
            Text("Your Privacy")
                .font(.wineDisplay)
                .foregroundStyle(WineTheme.cream)
        }
        .frame(maxWidth: .infinity)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WineMind works for you — not against you.")
                .font(.wineTitle3)
                .foregroundStyle(WineTheme.cream)

            Text("Choose what you want to share. You can change any of these at any time in Settings, or use the app entirely offline.")
                .font(.wineCallout)
                .italic()
                .foregroundStyle(WineTheme.mutedText)
                .lineSpacing(3)
        }
    }

    private var permissionsSection: some View {
        VStack(spacing: 12) {
            PermissionRow(
                icon: "icloud.fill",
                title: "iCloud Sync",
                description: "Back up your cellar to iCloud so it follows you across devices. Stored in your private iCloud — Apple cannot read it.",
                isOn: $allowsCloudSync,
                required: false
            )

            PermissionRow(
                icon: "person.3.fill",
                title: "Community Recommendations",
                description: "See wines highly rated by people with similar taste. Read-only — no data sent.",
                isOn: $allowsCommunityRecs,
                required: false
            )

            PermissionRow(
                icon: "arrow.up.heart.fill",
                title: "Contribute Anonymously",
                description: "Send your ratings to the community pool (no name, no notes, no photo). Helps other wine lovers find good bottles.",
                isOn: $allowsAnonymousContribution,
                required: false
            )
        }
    }

    private var policyLink: some View {
        Button {
            showingPolicy = true
        } label: {
            HStack {
                Image(systemName: "doc.text")
                Text("Read the full Privacy Policy")
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .padding()
            .background(WineTheme.cardGradient)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(WineTheme.gold)
        }
    }

    private var acceptButton: some View {
        VStack(spacing: 0) {
            Rectangle().fill(WineTheme.divider).frame(height: 0.5)
            VStack(spacing: 8) {
                Button {
                    consentStore.acceptPolicy(
                        cloudSync: allowsCloudSync,
                        anonymousContribution: allowsAnonymousContribution,
                        communityRecs: allowsCommunityRecs
                    )
                } label: {
                    Text("Accept & Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(WineButtonStyle(prominent: true))

                Text("By tapping Accept, you confirm you've read the Privacy Policy.")
                    .font(.wineCaption)
                    .foregroundStyle(WineTheme.dimText)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(WineTheme.background.ignoresSafeArea(edges: .bottom))
        }
    }
}

private struct PermissionRow: View {
    let icon: String
    let title: String
    let description: String
    @Binding var isOn: Bool
    let required: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(WineTheme.gold)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(.wineBody.weight(.semibold))
                        .foregroundStyle(WineTheme.cream)
                    if required {
                        Text("REQUIRED")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1)
                            .foregroundStyle(WineTheme.gold)
                    }
                }
                Text(description)
                    .font(.wineCaption)
                    .foregroundStyle(WineTheme.mutedText)
                    .lineSpacing(2)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(WineTheme.gold)
                .disabled(required)
        }
        .padding(14)
        .background(WineTheme.cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(WineTheme.divider, lineWidth: 0.5)
        }
    }
}
