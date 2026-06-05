import Foundation
import SwiftUI

/// GDPR consent state.
/// Each field represents a specific, separately-granted permission — never bundled.
struct PrivacyConsent: Codable, Equatable {
    /// User has read and accepted the privacy policy.
    var acceptedPrivacyPolicy: Bool
    /// Acceptance timestamp for audit.
    var acceptedAt: Date?
    /// Version of the policy they accepted — bumped when terms change.
    var acceptedPolicyVersion: Int

    /// Granular: allow ratings to be sent (anonymously) to the public DB for community recs.
    /// User can opt in/out independently of using the app.
    var allowsAnonymousContribution: Bool

    /// Granular: allow fetching community recommendations (read-only public DB queries).
    var allowsCommunityRecommendations: Bool

    /// Granular: allow CloudKit private sync (cross-device backup of personal wines).
    /// If false, app works offline-only with local SwiftData.
    var allowsCloudSync: Bool

    static let empty = PrivacyConsent(
        acceptedPrivacyPolicy: false,
        acceptedAt: nil,
        acceptedPolicyVersion: 0,
        allowsAnonymousContribution: false,
        allowsCommunityRecommendations: false,
        allowsCloudSync: false
    )

    /// Current policy version — bump this when privacy terms change to force re-consent.
    static let currentPolicyVersion = 1

    var needsReConsent: Bool {
        !acceptedPrivacyPolicy || acceptedPolicyVersion < Self.currentPolicyVersion
    }
}

@MainActor
final class PrivacyConsentStore: ObservableObject {
    static let shared = PrivacyConsentStore()

    @Published var consent: PrivacyConsent = .empty

    private let key = "winemind.privacyConsent"

    init() {
        load()
    }

    func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode(PrivacyConsent.self, from: data) {
            consent = decoded
        }
    }

    func save(_ consent: PrivacyConsent) {
        self.consent = consent
        if let data = try? JSONEncoder().encode(consent) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// Accept the policy with the user's granular choices.
    func acceptPolicy(
        cloudSync: Bool,
        anonymousContribution: Bool,
        communityRecs: Bool
    ) {
        let updated = PrivacyConsent(
            acceptedPrivacyPolicy: true,
            acceptedAt: Date(),
            acceptedPolicyVersion: PrivacyConsent.currentPolicyVersion,
            allowsAnonymousContribution: anonymousContribution,
            allowsCommunityRecommendations: communityRecs,
            allowsCloudSync: cloudSync
        )
        save(updated)
    }

    func updateAnonymousContribution(_ allowed: Bool) {
        var c = consent
        c.allowsAnonymousContribution = allowed
        save(c)
    }

    func updateCommunityRecs(_ allowed: Bool) {
        var c = consent
        c.allowsCommunityRecommendations = allowed
        save(c)
    }

    func updateCloudSync(_ allowed: Bool) {
        var c = consent
        c.allowsCloudSync = allowed
        save(c)
    }

    /// Reset on full account deletion.
    func reset() {
        consent = .empty
        UserDefaults.standard.removeObject(forKey: key)
    }
}
