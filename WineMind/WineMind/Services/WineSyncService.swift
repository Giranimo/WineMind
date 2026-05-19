import Foundation
import SwiftData

/// Restores wines from CloudKit to local SwiftData store on first launch after sign-in
@MainActor
final class WineSyncService {
    static let shared = WineSyncService()

    private let restoreCompleteKey = "winemind.cloudKitRestoreComplete"

    func restoreIfNeeded(context: ModelContext) async {
        guard !UserDefaults.standard.bool(forKey: restoreCompleteKey) else { return }

        do {
            let cloudWines = try await CloudKitService.shared.fetchUserWines()

            for data in cloudWines {
                // Check if wine already exists locally
                let id = data.id
                let descriptor = FetchDescriptor<Wine>(predicate: #Predicate { $0.id == id })
                let existing = try context.fetch(descriptor)
                if !existing.isEmpty { continue }

                let wine = Wine(
                    name: data.name,
                    winery: data.winery,
                    variety: data.variety,
                    region: data.region,
                    vintage: data.vintage,
                    score: data.score,
                    notes: data.notes,
                    photoData: data.photoData,
                    color: data.color,
                    body: data.body,
                    sweetness: data.sweetness
                )
                wine.id = data.id
                wine.dateAdded = data.dateAdded
                context.insert(wine)
            }

            try? context.save()
            UserDefaults.standard.set(true, forKey: restoreCompleteKey)
        } catch {
            // Silent failure — they can retry by deleting/reinstalling
            print("CloudKit restore failed: \(error.localizedDescription)")
        }
    }

    func markRestoreNeeded() {
        UserDefaults.standard.set(false, forKey: restoreCompleteKey)
    }
}
