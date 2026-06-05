import Foundation
import SwiftData
import UIKit

/// GDPR Article 20 — Right to data portability.
/// Exports everything we hold about the user into a machine-readable JSON archive.
@MainActor
final class DataExportService {
    static let shared = DataExportService()

    private let dateFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Build a complete export bundle.
    func buildExport(wines: [Wine], tasteProfile: TasteProfile, consent: PrivacyConsent) async throws -> URL {
        var contributorID: String?
        if consent.allowsAnonymousContribution {
            contributorID = try? await SecurityService.shared.contributorID()
        }

        let payload = ExportPayload(
            exportedAt: Date(),
            schemaVersion: 1,
            wines: wines.map { wineDTO(from: $0) },
            tasteProfile: TasteProfileDTO(from: tasteProfile),
            privacyConsent: ConsentDTO(from: consent),
            anonymousContributorID: contributorID,
            notes: "This file contains all data stored locally on your device by WineMind. Photo data is base64-encoded within each wine record."
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(payload)

        let filename = "winemind-export-\(timestamp()).json"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try data.write(to: url)
        return url
    }

    // MARK: - Mapping

    private func wineDTO(from wine: Wine) -> WineDTO {
        WineDTO(
            id: wine.id.uuidString,
            name: wine.name,
            winery: wine.winery,
            variety: wine.variety,
            region: wine.region,
            vintage: wine.vintage,
            score: wine.score,
            notes: wine.notes,
            color: wine.color.rawValue,
            body: wine.body.rawValue,
            sweetness: wine.sweetness.rawValue,
            dateAdded: wine.dateAdded,
            photoBase64: wine.photoData?.base64EncodedString()
        )
    }

    private func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: Date())
    }
}

// MARK: - DTOs (Codable representations stable across schema changes)

private struct ExportPayload: Codable {
    let exportedAt: Date
    let schemaVersion: Int
    let wines: [WineDTO]
    let tasteProfile: TasteProfileDTO
    let privacyConsent: ConsentDTO
    let anonymousContributorID: String?
    let notes: String
}

private struct WineDTO: Codable {
    let id: String
    let name: String
    let winery: String
    let variety: String
    let region: String
    let vintage: Int
    let score: Double
    let notes: String
    let color: String
    let body: String
    let sweetness: String
    let dateAdded: Date
    let photoBase64: String?
}

private struct TasteProfileDTO: Codable {
    let preferredColors: [String]
    let preferredBody: String?
    let preferredSweetness: String?
    let preferredFlavors: [String]
    let preferredVarieties: [String]
    let preferredRegions: [String]
    let experience: String

    init(from profile: TasteProfile) {
        self.preferredColors = profile.preferredColors.map { $0.rawValue }
        self.preferredBody = profile.preferredBody?.rawValue
        self.preferredSweetness = profile.preferredSweetness?.rawValue
        self.preferredFlavors = profile.preferredFlavors.map { $0.rawValue }
        self.preferredVarieties = Array(profile.preferredVarieties)
        self.preferredRegions = Array(profile.preferredRegions)
        self.experience = profile.experience.rawValue
    }
}

private struct ConsentDTO: Codable {
    let acceptedPrivacyPolicy: Bool
    let acceptedAt: Date?
    let acceptedPolicyVersion: Int
    let allowsAnonymousContribution: Bool
    let allowsCommunityRecommendations: Bool
    let allowsCloudSync: Bool

    init(from c: PrivacyConsent) {
        self.acceptedPrivacyPolicy = c.acceptedPrivacyPolicy
        self.acceptedAt = c.acceptedAt
        self.acceptedPolicyVersion = c.acceptedPolicyVersion
        self.allowsAnonymousContribution = c.allowsAnonymousContribution
        self.allowsCommunityRecommendations = c.allowsCommunityRecommendations
        self.allowsCloudSync = c.allowsCloudSync
    }
}
