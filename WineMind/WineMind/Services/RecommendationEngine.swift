import Foundation
import NaturalLanguage
import SwiftData

struct WineRecommendation: Identifiable {
    let id = UUID()
    let wine: Wine
    let score: Double // similarity score 0-1
    let reason: String
}

struct RecommendationEngine {

    // MARK: - Main Recommendations

    /// Build personalized recommendations from the user's rated collection
    func getRecommendations(from allWines: [Wine], topCount: Int = 5) -> [WineRecommendation] {
        guard allWines.count >= 2 else { return [] }

        // Build a taste profile from wines rated 7+
        let likedWines = allWines
            .filter { $0.score >= 7.0 }
            .sorted { $0.score > $1.score }

        guard !likedWines.isEmpty else { return [] }

        let profile = buildTasteProfile(from: likedWines)

        // Score every wine against the taste profile
        let otherWines = allWines.filter { $0.score < 7.0 && $0.score > 0 }

        var recommendations: [WineRecommendation] = []

        for wine in otherWines {
            let profileMatch = profileSimilarity(wine: wine, profile: profile)

            // Also find the single best liked-wine match for the reason text
            var bestMatch: Wine?
            var bestSim = 0.0
            for liked in likedWines {
                let sim = wineSimilarity(between: wine, and: liked)
                if sim > bestSim {
                    bestSim = sim
                    bestMatch = liked
                }
            }

            // Blend profile match (70%) with best individual match (30%)
            let blended = profileMatch * 0.7 + bestSim * 0.3

            if blended > 0.25, let match = bestMatch {
                let reason = buildReason(wine: wine, similarTo: match, profileMatch: profileMatch)
                recommendations.append(WineRecommendation(wine: wine, score: blended, reason: reason))
            }
        }

        // Top-rated wines the user already loves
        let topRated = likedWines.prefix(topCount).map { wine in
            WineRecommendation(
                wine: wine,
                score: wine.score / 10.0,
                reason: "One of your top-rated wines"
            )
        }

        let similar = recommendations
            .sorted { $0.score > $1.score }
            .prefix(topCount)

        return Array(topRated) + Array(similar)
    }

    /// Find wines similar to a specific wine
    func findSimilar(to target: Wine, in allWines: [Wine], limit: Int = 5) -> [WineRecommendation] {
        allWines
            .filter { $0.id != target.id }
            .map { wine in
                let sim = wineSimilarity(between: wine, and: target)
                let reason = buildReason(wine: wine, similarTo: target, profileMatch: nil)
                return WineRecommendation(wine: wine, score: sim, reason: reason)
            }
            .filter { $0.score > 0.2 }
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Taste Profile

    struct TasteProfile {
        var preferredVarieties: [String: Double]  // variety -> weighted frequency
        var preferredRegions: [String: Double]
        var preferredColors: [WineColor: Double]
        var preferredBody: [WineBody: Double]
        var preferredSweetness: [WineSweetness: Double]
        var avgVintage: Double
        var tastingKeywords: [String: Double]     // keywords from notes -> frequency
    }

    private func buildTasteProfile(from likedWines: [Wine]) -> TasteProfile {
        var varieties: [String: Double] = [:]
        var regions: [String: Double] = [:]
        var colors: [WineColor: Double] = [:]
        var bodies: [WineBody: Double] = [:]
        var sweetness: [WineSweetness: Double] = [:]
        var vintageSum = 0.0
        var keywords: [String: Double] = [:]

        for wine in likedWines {
            // Weight by score (a 10 counts more than a 7)
            let weight = wine.score / 10.0

            if !wine.variety.isEmpty {
                let key = wine.variety.lowercased()
                varieties[key, default: 0] += weight
            }
            if !wine.region.isEmpty {
                let key = wine.region.lowercased()
                regions[key, default: 0] += weight
            }
            colors[wine.color, default: 0] += weight
            bodies[wine.body, default: 0] += weight
            sweetness[wine.sweetness, default: 0] += weight
            vintageSum += Double(wine.vintage) * weight

            // Extract keywords from tasting notes using NaturalLanguage
            let noteKeywords = extractKeywords(from: wine.notes)
            for kw in noteKeywords {
                keywords[kw, default: 0] += weight
            }
        }

        let totalWeight = likedWines.reduce(0.0) { $0 + $1.score / 10.0 }

        return TasteProfile(
            preferredVarieties: varieties,
            preferredRegions: regions,
            preferredColors: colors,
            preferredBody: bodies,
            preferredSweetness: sweetness,
            avgVintage: totalWeight > 0 ? vintageSum / totalWeight : 2020,
            tastingKeywords: keywords
        )
    }

    // MARK: - Apple NaturalLanguage Keyword Extraction

    private func extractKeywords(from text: String) -> [String] {
        guard !text.isEmpty else { return [] }

        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text.lowercased()

        var keywords: [String] = []
        let options: NLTagger.Options = [.omitPunctuation, .omitWhitespace, .joinNames]

        tagger.enumerateTags(in: text.lowercased().startIndex..<text.lowercased().endIndex,
                             unit: .word,
                             scheme: .lexicalClass,
                             options: options) { tag, range in
            if let tag = tag {
                let word = String(text.lowercased()[range])
                // Keep adjectives and nouns — these describe wine character
                // e.g. "fruity", "oaky", "smooth", "cherry", "vanilla", "tannins"
                if (tag == .adjective || tag == .noun) && word.count > 2 {
                    keywords.append(word)
                }
            }
            return true
        }

        return keywords
    }

    // MARK: - Similarity Scoring

    /// How well a wine matches the user's overall taste profile
    private func profileSimilarity(wine: Wine, profile: TasteProfile) -> Double {
        var score = 0.0

        // Variety preference (0.30)
        if !wine.variety.isEmpty {
            let key = wine.variety.lowercased()
            if let pref = profile.preferredVarieties[key] {
                let maxPref = profile.preferredVarieties.values.max() ?? 1.0
                score += 0.30 * (pref / maxPref)
            }
        }

        // Region preference (0.20)
        if !wine.region.isEmpty {
            let key = wine.region.lowercased()
            if let pref = profile.preferredRegions[key] {
                let maxPref = profile.preferredRegions.values.max() ?? 1.0
                score += 0.20 * (pref / maxPref)
            }
        }

        // Color preference (0.15)
        if let pref = profile.preferredColors[wine.color] {
            let maxPref = profile.preferredColors.values.max() ?? 1.0
            score += 0.15 * (pref / maxPref)
        }

        // Body preference (0.10)
        if let pref = profile.preferredBody[wine.body] {
            let maxPref = profile.preferredBody.values.max() ?? 1.0
            score += 0.10 * (pref / maxPref)
        }

        // Sweetness preference (0.10)
        if let pref = profile.preferredSweetness[wine.sweetness] {
            let maxPref = profile.preferredSweetness.values.max() ?? 1.0
            score += 0.10 * (pref / maxPref)
        }

        // Tasting notes keyword overlap (0.15) — powered by NaturalLanguage
        if !wine.notes.isEmpty && !profile.tastingKeywords.isEmpty {
            let wineKeywords = Set(extractKeywords(from: wine.notes))
            let profileKeywordSet = Set(profile.tastingKeywords.keys)
            let overlap = wineKeywords.intersection(profileKeywordSet)
            if !wineKeywords.isEmpty {
                let keywordScore = Double(overlap.count) / Double(max(wineKeywords.count, 1))
                score += 0.15 * min(keywordScore, 1.0)
            }
        }

        return score
    }

    /// Direct wine-to-wine similarity
    private func wineSimilarity(between a: Wine, and b: Wine) -> Double {
        var score = 0.0

        // Variety match (strongest signal)
        if !a.variety.isEmpty && a.variety.lowercased() == b.variety.lowercased() {
            score += 0.30
        }

        // Color match
        if a.color == b.color {
            score += 0.20
        }

        // Region match
        if !a.region.isEmpty && a.region.lowercased() == b.region.lowercased() {
            score += 0.15
        }

        // Body match
        if a.body == b.body {
            score += 0.10
        }

        // Sweetness match
        if a.sweetness == b.sweetness {
            score += 0.05
        }

        // Vintage proximity (within 5 years)
        let vintageGap = abs(a.vintage - b.vintage)
        if vintageGap <= 5 {
            score += 0.05 * (1.0 - Double(vintageGap) / 5.0)
        }

        // Tasting notes similarity using NaturalLanguage
        if !a.notes.isEmpty && !b.notes.isEmpty {
            let noteSim = notesSimilarity(a.notes, b.notes)
            score += 0.15 * noteSim
        }

        return score
    }

    /// Compare tasting notes using Apple NaturalLanguage embedding distance
    private func notesSimilarity(_ textA: String, _ textB: String) -> Double {
        if let embedding = NLEmbedding.sentenceEmbedding(for: .english) {
            let distance = embedding.distance(between: textA.lowercased(), and: textB.lowercased())
            // NLEmbedding distance is 0 (identical) to 2 (opposite)
            // Convert to 0-1 similarity
            return max(0, 1.0 - distance / 2.0)
        }

        // Fallback: keyword overlap
        let kwA = Set(extractKeywords(from: textA))
        let kwB = Set(extractKeywords(from: textB))
        guard !kwA.isEmpty || !kwB.isEmpty else { return 0 }
        let overlap = kwA.intersection(kwB).count
        let union = kwA.union(kwB).count
        return Double(overlap) / Double(max(union, 1))
    }

    // MARK: - Reason Builder

    private func buildReason(wine: Wine, similarTo match: Wine, profileMatch: Double?) -> String {
        var reasons: [String] = []

        if !wine.variety.isEmpty && wine.variety.lowercased() == match.variety.lowercased() {
            reasons.append("same grape (\(wine.variety))")
        }
        if !wine.region.isEmpty && wine.region.lowercased() == match.region.lowercased() {
            reasons.append("same region (\(wine.region))")
        }
        if wine.color == match.color && reasons.isEmpty {
            reasons.append("same style")
        }
        if wine.body == match.body {
            reasons.append("similar body")
        }

        // If notes are similar, mention it
        if !wine.notes.isEmpty && !match.notes.isEmpty {
            let sim = notesSimilarity(wine.notes, match.notes)
            if sim > 0.5 {
                reasons.append("similar tasting notes")
            }
        }

        if let pm = profileMatch, pm > 0.6 {
            return "Matches your taste profile — \(reasons.joined(separator: ", "))"
        }

        if reasons.isEmpty {
            return "Similar profile to \(match.name)"
        }
        return "Like \(match.name) — \(reasons.joined(separator: ", "))"
    }
}
