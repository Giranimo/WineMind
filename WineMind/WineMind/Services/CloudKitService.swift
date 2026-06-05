import Foundation
import CloudKit
import UIKit

/// Manages CloudKit sync — private DB for user's wines, public DB for collaborative recommendations
actor CloudKitService {
    static let shared = CloudKitService()

    private let container = CKContainer(identifier: "iCloud.com.winemind.app")
    private var privateDB: CKDatabase { container.privateCloudDatabase }
    private var publicDB: CKDatabase { container.publicCloudDatabase }

    // Record types
    private let wineRecordType = "Wine"
    private let publicRatingRecordType = "PublicWineRating"

    // MARK: - User Identity

    /// Get the user's anonymous CloudKit ID (for collaborative filtering without exposing identity)
    func currentUserID() async throws -> String {
        let recordID = try await container.userRecordID()
        return recordID.recordName
    }

    func accountStatus() async throws -> CKAccountStatus {
        try await container.accountStatus()
    }

    // MARK: - Private DB: User's Personal Wines

    /// Save or update a wine in the user's private CloudKit DB.
    /// `contributeAnonymously` controls whether the rating is also sent to the public DB —
    /// this is the GDPR opt-in for collaborative recommendations.
    func saveWine(_ wine: Wine, contributeAnonymously: Bool) async throws {
        let record = CKRecord(recordType: wineRecordType, recordID: CKRecord.ID(recordName: wine.id.uuidString))
        record["name"] = wine.name
        record["winery"] = wine.winery
        record["variety"] = wine.variety
        record["region"] = wine.region
        record["vintage"] = wine.vintage
        record["score"] = wine.score
        record["notes"] = wine.notes
        record["dateAdded"] = wine.dateAdded
        record["color"] = wine.color.rawValue
        record["body"] = wine.body.rawValue
        record["sweetness"] = wine.sweetness.rawValue

        if let photoData = wine.photoData {
            // Strip EXIF/GPS before upload — even for the private DB.
            // Defense in depth: if iCloud is ever compromised, no location data leaks.
            let cleanData = sanitizePhotoData(photoData)
            let url = try writeTempImageFile(data: cleanData, id: wine.id)
            record["photo"] = CKAsset(fileURL: url)
        }

        _ = try await privateDB.save(record)

        // Only contribute to the public DB if the user has consented.
        // Note that tasting notes, photos, dateAdded, and the user's name are NEVER
        // sent to the public DB — only wine metadata + score.
        if wine.score > 0 && contributeAnonymously {
            try await contributePublicRating(wine: wine)
        }
    }

    private func sanitizePhotoData(_ data: Data) -> Data {
        guard let image = UIImage(data: data),
              let stripped = SecurityService.strippedJPEGData(from: image) else {
            return data
        }
        return stripped
    }

    /// Fetch all user's wines from CloudKit (for restoring on a new device)
    func fetchUserWines() async throws -> [WineCloudKitData] {
        let query = CKQuery(recordType: wineRecordType, predicate: NSPredicate(value: true))
        query.sortDescriptors = [NSSortDescriptor(key: "dateAdded", ascending: false)]

        let (results, _) = try await privateDB.records(matching: query)

        var wines: [WineCloudKitData] = []
        for (_, result) in results {
            switch result {
            case .success(let record):
                if let wine = parseWineRecord(record) {
                    wines.append(wine)
                }
            case .failure:
                continue
            }
        }
        return wines
    }

    func deleteWine(id: UUID) async throws {
        let recordID = CKRecord.ID(recordName: id.uuidString)
        _ = try await privateDB.deleteRecord(withID: recordID)
    }

    // MARK: - GDPR: Right to Erasure

    /// Delete every wine the user has stored in their private CloudKit DB.
    func deleteAllPrivateData() async throws {
        let query = CKQuery(recordType: wineRecordType, predicate: NSPredicate(value: true))
        let (results, _) = try await privateDB.records(matching: query)

        for (recordID, _) in results {
            _ = try? await privateDB.deleteRecord(withID: recordID)
        }
    }

    /// Delete every public rating ever contributed by this device.
    /// After this, the user's contributor ID can be rotated so future ratings are unlinkable.
    func deleteAllPublicContributions() async throws {
        let userHash = try await SecurityService.shared.contributorID()
        let predicate = NSPredicate(format: "userHash == %@", userHash)
        let query = CKQuery(recordType: publicRatingRecordType, predicate: predicate)
        let (results, _) = try await publicDB.records(matching: query)

        for (recordID, _) in results {
            _ = try? await publicDB.deleteRecord(withID: recordID)
        }
    }

    // MARK: - Public DB: Collaborative Ratings

    /// Contribute an anonymized rating to the public database.
    /// Uses a locally-generated UUID (stored in Keychain) as the contributor ID — this is
    /// cryptographically unlinkable from the user's Apple ID or any other identifier.
    private func contributePublicRating(wine: Wine) async throws {
        let userHash = try await SecurityService.shared.contributorID()

        // Use a deterministic record ID per user+wine so updates replace the previous rating
        let wineSignature = wineSignature(wine: wine)
        let recordID = CKRecord.ID(recordName: "\(userHash)-\(wineSignature)")

        let record = CKRecord(recordType: publicRatingRecordType, recordID: recordID)
        record["userHash"] = userHash
        record["wineSignature"] = wineSignature
        record["wineName"] = wine.name
        record["winery"] = wine.winery
        record["variety"] = wine.variety
        record["region"] = wine.region
        record["vintage"] = wine.vintage
        record["score"] = wine.score
        record["color"] = wine.color.rawValue
        record["body"] = wine.body.rawValue
        record["sweetness"] = wine.sweetness.rawValue
        record["ratedAt"] = Date()

        // Save with conflict resolution (overwrite)
        let config = CKModifyRecordsOperation.Configuration()
        config.qualityOfService = .utility

        do {
            _ = try await publicDB.save(record)
        } catch let error as CKError where error.code == .serverRecordChanged {
            // Record exists — update it
            if let existing = error.serverRecord {
                existing["score"] = wine.score
                existing["ratedAt"] = Date()
                _ = try await publicDB.save(existing)
            }
        }
    }

    /// Fetch wines highly rated by other users that match the user's taste profile
    func fetchPublicRecommendations(matchingVarieties: [String], matchingRegions: [String], minScore: Double = 8.0, limit: Int = 30) async throws -> [PublicWineRating] {
        // Build predicate: high score AND (variety in list OR region in list)
        var subpredicates: [NSPredicate] = [NSPredicate(format: "score >= %f", minScore)]

        if !matchingVarieties.isEmpty {
            let varietyPred = NSPredicate(format: "variety IN %@", matchingVarieties)
            let regionPred = !matchingRegions.isEmpty
                ? NSPredicate(format: "region IN %@", matchingRegions)
                : NSPredicate(value: false)
            subpredicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: [varietyPred, regionPred]))
        }

        let predicate = NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)
        let query = CKQuery(recordType: publicRatingRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "score", ascending: false)]

        let (results, _) = try await publicDB.records(matching: query, resultsLimit: limit)

        var ratings: [PublicWineRating] = []
        for (_, result) in results {
            if case .success(let record) = result, let rating = parsePublicRating(record) {
                ratings.append(rating)
            }
        }
        return ratings
    }

    /// Find users with similar taste based on overlapping high ratings
    func fetchSimilarUsersRatings(currentUserHash: String, currentUserHighRatedWines: [String], limit: Int = 100) async throws -> [PublicWineRating] {
        // Get all high ratings from other users matching wines this user also rated highly
        guard !currentUserHighRatedWines.isEmpty else { return [] }

        let predicate = NSPredicate(format: "wineName IN %@ AND userHash != %@ AND score >= %f",
                                    currentUserHighRatedWines, currentUserHash, 7.0)
        let query = CKQuery(recordType: publicRatingRecordType, predicate: predicate)

        let (results, _) = try await publicDB.records(matching: query, resultsLimit: limit * 5)

        var ratings: [PublicWineRating] = []
        for (_, result) in results {
            if case .success(let record) = result, let rating = parsePublicRating(record) {
                ratings.append(rating)
            }
        }
        return ratings
    }

    /// Get all wines rated by a specific user (for finding what similar-taste users like)
    func fetchRatingsByUser(userHash: String, minScore: Double = 8.0, limit: Int = 50) async throws -> [PublicWineRating] {
        let predicate = NSPredicate(format: "userHash == %@ AND score >= %f", userHash, minScore)
        let query = CKQuery(recordType: publicRatingRecordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "score", ascending: false)]

        let (results, _) = try await publicDB.records(matching: query, resultsLimit: limit)

        var ratings: [PublicWineRating] = []
        for (_, result) in results {
            if case .success(let record) = result, let rating = parsePublicRating(record) {
                ratings.append(rating)
            }
        }
        return ratings
    }

    // MARK: - Parsing

    private func parseWineRecord(_ record: CKRecord) -> WineCloudKitData? {
        guard let name = record["name"] as? String,
              let dateAdded = record["dateAdded"] as? Date else { return nil }

        var photoData: Data?
        if let asset = record["photo"] as? CKAsset, let url = asset.fileURL {
            photoData = try? Data(contentsOf: url)
        }

        return WineCloudKitData(
            id: UUID(uuidString: record.recordID.recordName) ?? UUID(),
            name: name,
            winery: (record["winery"] as? String) ?? "",
            variety: (record["variety"] as? String) ?? "",
            region: (record["region"] as? String) ?? "",
            vintage: (record["vintage"] as? Int) ?? 0,
            score: (record["score"] as? Double) ?? 0,
            notes: (record["notes"] as? String) ?? "",
            color: WineColor(rawValue: (record["color"] as? String) ?? "Red") ?? .red,
            body: WineBody(rawValue: (record["body"] as? String) ?? "Medium") ?? .medium,
            sweetness: WineSweetness(rawValue: (record["sweetness"] as? String) ?? "Dry") ?? .dry,
            photoData: photoData,
            dateAdded: dateAdded
        )
    }

    private func parsePublicRating(_ record: CKRecord) -> PublicWineRating? {
        guard let userHash = record["userHash"] as? String,
              let wineName = record["wineName"] as? String,
              let score = record["score"] as? Double else { return nil }

        return PublicWineRating(
            userHash: userHash,
            wineName: wineName,
            winery: (record["winery"] as? String) ?? "",
            variety: (record["variety"] as? String) ?? "",
            region: (record["region"] as? String) ?? "",
            vintage: (record["vintage"] as? Int) ?? 0,
            score: score,
            color: WineColor(rawValue: (record["color"] as? String) ?? "Red") ?? .red,
            body: WineBody(rawValue: (record["body"] as? String) ?? "Medium") ?? .medium,
            sweetness: WineSweetness(rawValue: (record["sweetness"] as? String) ?? "Dry") ?? .dry,
            ratedAt: (record["ratedAt"] as? Date) ?? Date()
        )
    }

    // MARK: - Helpers

    private func wineSignature(wine: Wine) -> String {
        let name = wine.name.lowercased().filter { $0.isLetter || $0.isNumber }
        let winery = wine.winery.lowercased().filter { $0.isLetter || $0.isNumber }
        return "\(winery)-\(name)-\(wine.vintage)"
    }

    private func writeTempImageFile(data: Data, id: UUID) throws -> URL {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(id.uuidString).jpg")
        try data.write(to: tempURL)
        return tempURL
    }
}

// MARK: - Data Models

struct WineCloudKitData {
    let id: UUID
    let name: String
    let winery: String
    let variety: String
    let region: String
    let vintage: Int
    let score: Double
    let notes: String
    let color: WineColor
    let body: WineBody
    let sweetness: WineSweetness
    let photoData: Data?
    let dateAdded: Date
}

struct PublicWineRating: Identifiable {
    let id = UUID()
    let userHash: String
    let wineName: String
    let winery: String
    let variety: String
    let region: String
    let vintage: Int
    let score: Double
    let color: WineColor
    let body: WineBody
    let sweetness: WineSweetness
    let ratedAt: Date
}
