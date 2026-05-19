import Foundation
import CloudKit
import NaturalLanguage

/// Combines local taste profile with collaborative filtering from CloudKit public ratings
@MainActor
final class CollaborativeRecommender: ObservableObject {
    static let shared = CollaborativeRecommender()

    @Published var publicRecommendations: [PublicRecommendation] = []
    @Published var isLoading = false
    @Published var lastError: String?

    private let localEngine = RecommendationEngine()

    // MARK: - Public Recommendations

    /// Fetch wines that users with similar taste rated highly
    func refreshRecommendations(from userWines: [Wine]) async {
        guard userWines.count >= 3 else {
            publicRecommendations = []
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Step 1: Get the user's high-rated wines (their taste signals)
            let userHighRated = userWines.filter { $0.score >= 7.0 }
            guard !userHighRated.isEmpty else {
                publicRecommendations = []
                return
            }

            let favoriteVarieties = Array(Set(userHighRated.map { $0.variety }.filter { !$0.isEmpty }))
            let favoriteRegions = Array(Set(userHighRated.map { $0.region }.filter { !$0.isEmpty }))
            let highRatedNames = userHighRated.map { $0.name }

            // Step 2: Two strategies in parallel
            async let varietyMatched = CloudKitService.shared.fetchPublicRecommendations(
                matchingVarieties: favoriteVarieties,
                matchingRegions: favoriteRegions,
                minScore: 8.0,
                limit: 30
            )

            let userID = try await CloudKitService.shared.currentUserID()
            let userHash = hashUserID(userID)

            async let similarUserRatings = CloudKitService.shared.fetchSimilarUsersRatings(
                currentUserHash: userHash,
                currentUserHighRatedWines: highRatedNames,
                limit: 100
            )

            let (varietyResults, similarRatings) = try await (varietyMatched, similarUserRatings)

            // Step 3: Find users with most overlap (similar-taste users)
            let userOverlap = Dictionary(grouping: similarRatings, by: { $0.userHash })
                .mapValues { $0.count }

            let similarUsers = userOverlap
                .filter { $0.value >= 2 } // at least 2 wines in common
                .sorted { $0.value > $1.value }
                .prefix(10)
                .map { $0.key }

            // Step 4: Get top wines from those similar-taste users
            var similarUserWines: [PublicWineRating] = []
            for similarUserHash in similarUsers {
                if let ratings = try? await CloudKitService.shared.fetchRatingsByUser(
                    userHash: similarUserHash,
                    minScore: 8.0,
                    limit: 10
                ) {
                    similarUserWines.append(contentsOf: ratings)
                }
            }

            // Step 5: Combine, dedupe, filter out wines user already has, rank
            let userOwnedSignatures = Set(userWines.map { wineSignature(name: $0.name, winery: $0.winery, vintage: $0.vintage) })

            var combined: [String: PublicRecommendation] = [:]

            // Variety/region matches — pure profile match
            for rating in varietyResults {
                let sig = wineSignature(name: rating.wineName, winery: rating.winery, vintage: rating.vintage)
                guard !userOwnedSignatures.contains(sig) else { continue }

                if combined[sig] == nil {
                    let reason = profileMatchReason(rating: rating, userVarieties: favoriteVarieties, userRegions: favoriteRegions)
                    combined[sig] = PublicRecommendation(
                        rating: rating,
                        matchScore: rating.score / 10.0,
                        source: .profileMatch,
                        reason: reason
                    )
                }
            }

            // Similar-user recs — collaborative match (weighted higher)
            for rating in similarUserWines {
                let sig = wineSignature(name: rating.wineName, winery: rating.winery, vintage: rating.vintage)
                guard !userOwnedSignatures.contains(sig) else { continue }

                let overlapCount = userOverlap[rating.userHash] ?? 1
                let collabScore = (rating.score / 10.0) * min(Double(overlapCount) / 5.0, 1.0)

                if let existing = combined[sig] {
                    // Boost score if both strategies recommend it
                    combined[sig] = PublicRecommendation(
                        rating: existing.rating,
                        matchScore: min(1.0, existing.matchScore + collabScore * 0.4),
                        source: .both,
                        reason: "Loved by people with similar taste"
                    )
                } else {
                    combined[sig] = PublicRecommendation(
                        rating: rating,
                        matchScore: collabScore,
                        source: .collaborativeMatch,
                        reason: "People with similar taste rated this \(String(format: "%.1f", rating.score))"
                    )
                }
            }

            // Step 6: Sort and take top results
            let sorted = combined.values
                .sorted { $0.matchScore > $1.matchScore }
                .prefix(20)

            publicRecommendations = Array(sorted)
            lastError = nil
        } catch {
            lastError = "Could not fetch recommendations: \(error.localizedDescription)"
        }
    }

    // MARK: - Helpers

    private func hashUserID(_ userID: String) -> String {
        let data = userID.data(using: .utf8) ?? Data()
        let hash = data.reduce(into: UInt64(5381)) { result, byte in
            result = result &* 33 &+ UInt64(byte)
        }
        return String(hash, radix: 36)
    }

    private func wineSignature(name: String, winery: String, vintage: Int) -> String {
        let n = name.lowercased().filter { $0.isLetter || $0.isNumber }
        let w = winery.lowercased().filter { $0.isLetter || $0.isNumber }
        return "\(w)-\(n)-\(vintage)"
    }

    private func profileMatchReason(rating: PublicWineRating, userVarieties: [String], userRegions: [String]) -> String {
        var parts: [String] = []
        if userVarieties.contains(rating.variety) && !rating.variety.isEmpty {
            parts.append(rating.variety)
        }
        if userRegions.contains(rating.region) && !rating.region.isEmpty {
            parts.append("from \(rating.region)")
        }
        if parts.isEmpty {
            return "Highly rated by the community"
        }
        return "Matches your love of \(parts.joined(separator: " "))"
    }
}

// MARK: - Models

struct PublicRecommendation: Identifiable {
    let id = UUID()
    let rating: PublicWineRating
    let matchScore: Double  // 0-1
    let source: RecommendationSource
    let reason: String
}

enum RecommendationSource {
    case profileMatch       // matches user's variety/region preferences
    case collaborativeMatch // similar-taste users rated it highly
    case both               // both strategies agree

    var label: String {
        switch self {
        case .profileMatch: return "Your taste"
        case .collaborativeMatch: return "Similar taste"
        case .both: return "Top pick"
        }
    }

    var icon: String {
        switch self {
        case .profileMatch: return "person.crop.circle"
        case .collaborativeMatch: return "person.3.fill"
        case .both: return "sparkles"
        }
    }
}
