import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                WineTheme.backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Privacy Policy")
                            .font(.wineDisplay)
                            .foregroundStyle(WineTheme.cream)

                        Text("Last updated: " + Date().formatted(date: .long, time: .omitted))
                            .font(.wineCaption)
                            .italic()
                            .foregroundStyle(WineTheme.dimText)

                        GoldDivider().padding(.vertical, 8)

                        section("Plain-English Summary", """
                        WineMind is designed to be private by default. We use Apple's CloudKit so your wines stay in your private iCloud — not on any third-party server. The only data ever shared with anyone else is anonymized rating data, and only if you explicitly opt in.
                        """)

                        section("What We Collect On Your Device", """
                        • Wines you scan or enter — name, winery, variety, region, vintage, your score, tasting notes, and the photo you took
                        • Your taste profile from the calibration quiz
                        • Your privacy consent choices
                        • A randomly-generated UUID stored in iOS Keychain (used only if you opt into community contributions)
                        """)

                        section("What's Sent to iCloud (Your Private Database)", """
                        If you enable iCloud Sync, the wines and metadata above are stored in YOUR private iCloud database. We cannot read it. Apple cannot read it (it's encrypted with your iCloud key). Only you can.

                        Photos are stripped of GPS and EXIF metadata before being uploaded.
                        """)

                        section("What's Sent to the Community Pool (Public Database)", """
                        If you enable "Contribute Anonymously," we send only this for each rated wine:

                        • Wine name, winery, variety, region, vintage
                        • Your score (1–10)
                        • Color, body, sweetness
                        • A locally-generated anonymous ID

                        We never send: your tasting notes, your photo, your name, your email, your Apple ID, your location, your device identifiers, the date you tried the wine, or anything else.

                        The anonymous ID is a UUID generated on your device. It is NOT derived from your Apple ID. We cannot use it to identify you. Other users see only the score, not who rated it.
                        """)

                        section("What We Do Not Collect", """
                        • Crash reports
                        • Analytics events
                        • Advertising identifiers
                        • Your location
                        • Your contacts
                        • Anything outside the app
                        """)

                        section("Third Parties", """
                        WineMind talks to Apple's iCloud only. We do not use:
                        • Google Analytics, Firebase, Mixpanel, or any analytics service
                        • Facebook, Twitter, TikTok, or any social SDK
                        • Stripe, RevenueCat, or any payment processor
                        • External AI APIs (wine recognition uses Apple Vision, on-device)
                        """)

                        section("Your GDPR Rights", """
                        Under EU/UK GDPR, you have the right to:

                        • Access your data — Tap "Export My Data" in Settings to download a complete JSON archive
                        • Correct your data — Edit any wine or quiz answer at any time
                        • Erase your data — Tap "Delete Everything" in Settings to wipe all local + iCloud data instantly
                        • Restrict processing — Toggle off community contribution in Settings
                        • Portability — The exported JSON is machine-readable and easy to import elsewhere
                        • Object — Decline any optional permission with no impact on app function
                        • Withdraw consent — Revoke any granular permission at any time in Settings
                        """)

                        section("Data Retention", """
                        Your data lives on your device and in your private iCloud until you delete it. There is no server-side retention because there is no server we control. If you opt into community contributions, your anonymous ratings remain in the public CloudKit pool until you tap "Delete Everything" — which removes them too.
                        """)

                        section("Children", """
                        WineMind is intended for users 18 and older (wine, after all). We do not knowingly collect data from anyone under 18.
                        """)

                        section("Contact", """
                        Questions or requests? Email the developer at the address shown in App Store Connect for this app.
                        """)

                        Text("Policy version: \(PrivacyConsent.currentPolicyVersion)")
                            .font(.wineCaption)
                            .foregroundStyle(WineTheme.dimText)
                            .padding(.top, 20)

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(WineTheme.gold)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(2)
                .foregroundStyle(WineTheme.gold)
            Text(body)
                .font(.wineCallout)
                .foregroundStyle(WineTheme.cream)
                .lineSpacing(4)
        }
        .padding(.top, 8)
    }
}
