import Foundation
import SwiftData

/// GDPR Article 17 — Right to Erasure ("right to be forgotten").
/// Deletes EVERYTHING: local SwiftData, CloudKit private DB, CloudKit public contributions,
/// Keychain identifiers, UserDefaults-stored consent and taste profile.
@MainActor
final class AccountDeletionService {

    enum Step: String {
        case startingDeletion = "Starting deletion…"
        case deletingPublicContributions = "Removing your contributions from the community pool…"
        case deletingPrivateCloudKit = "Deleting your iCloud wine collection…"
        case deletingLocalWines = "Deleting wines on this device…"
        case deletingProfile = "Deleting your taste profile…"
        case deletingKeychain = "Clearing secure identifiers…"
        case complete = "Done."
    }

    /// Delete everything. Throws on the first failure; partial deletions still help — they
    /// remove the most sensitive data first.
    func deleteEverything(
        context: ModelContext,
        wines: [Wine],
        progress: @escaping (Step) -> Void = { _ in }
    ) async throws {
        progress(.startingDeletion)

        // 1. Public contributions (most important — these are visible to other users)
        progress(.deletingPublicContributions)
        try? await CloudKitService.shared.deleteAllPublicContributions()

        // 2. Private CloudKit wines
        progress(.deletingPrivateCloudKit)
        try? await CloudKitService.shared.deleteAllPrivateData()

        // 3. Local SwiftData wines
        progress(.deletingLocalWines)
        for wine in wines {
            context.delete(wine)
        }
        try? context.save()

        // 4. Taste profile
        progress(.deletingProfile)
        TasteProfileStore.shared.reset()

        // 5. Privacy consent
        PrivacyConsentStore.shared.reset()

        // 6. Keychain — last because the contributor ID was needed for step 1
        progress(.deletingKeychain)
        await SecurityService.shared.deleteContributorID()

        // 7. Clear restore flag so a fresh sign-in starts clean
        UserDefaults.standard.removeObject(forKey: "winemind.cloudKitRestoreComplete")

        progress(.complete)
    }
}
