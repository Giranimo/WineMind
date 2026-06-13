import Foundation
import SwiftData

/// Predicts whether the user will enjoy a wine based on their taste profile
/// and the community's ratings of similar wines.
struct WinePredictor {

    /// Predict the user's reaction to a wine they're about to try
    func predict(
        wineInfo: WineInfo,
        userWines: [Wine],
        tasteProfile: TasteProfile = .empty,
        publicRatings: [PublicWineRating] = []
    ) -> WinePrediction {
        let ratedWines = userWines.filter { $0.score > 0 }
        let hasProfile = tasteProfile.isComplete

        // Short-circuit: re-scanning a wine the user already rated
        if !wineInfo.name.isEmpty {
            let fold: (String) -> String = {
                $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            }
            let foldedName = fold(wineInfo.name)
            let foldedWinery = fold(wineInfo.winery)
            if let existing = ratedWines.first(where: {
                fold($0.name) == foldedName &&
                (foldedWinery.isEmpty || fold($0.winery) == foldedWinery)
            }) {
                return WinePrediction(
                    verdict: verdictFor(score: existing.score, confidence: 1.0),
                    confidence: 1.0,
                    reasons: ["You've already rated this wine \(String(format: "%.1f", existing.score))"],
                    predictedScore: existing.score
                )
            }
        }

        // If no rated wines AND no quiz profile, we genuinely can't predict
        guard ratedWines.count >= 3 || hasProfile else {
            return WinePrediction(
                verdict: .unknown,
                confidence: 0,
                reasons: ["Complete the taste quiz to unlock predictions"]
            )
        }

        var signals: [Signal] = []

        // SIGNAL 0: Quiz-derived taste profile (weight scales down as user rates more wines)
        if hasProfile {
            let profileWeight = profileWeightFor(ratedCount: ratedWines.count)
            signals.append(contentsOf: signalsFromTasteProfile(
                wineInfo: wineInfo,
                profile: tasteProfile,
                baseWeight: profileWeight
            ))
        }

        // SIGNAL 1: Same variety match
        if !wineInfo.variety.isEmpty {
            let sameVariety = ratedWines.filter {
                $0.variety.lowercased() == wineInfo.variety.lowercased()
            }
            if !sameVariety.isEmpty {
                let avgScore = sameVariety.reduce(0.0) { $0 + $1.score } / Double(sameVariety.count)
                let weight = min(Double(sameVariety.count) / 5.0, 1.0)
                signals.append(Signal(
                    score: avgScore,
                    weight: 0.35 * weight,
                    reason: "You've rated \(wineInfo.variety) wines \(String(format: "%.1f", avgScore)) on average"
                ))
            }
        }

        // SIGNAL 2: Same region match
        if !wineInfo.region.isEmpty {
            let sameRegion = ratedWines.filter {
                $0.region.lowercased() == wineInfo.region.lowercased()
            }
            if !sameRegion.isEmpty {
                let avgScore = sameRegion.reduce(0.0) { $0 + $1.score } / Double(sameRegion.count)
                let weight = min(Double(sameRegion.count) / 5.0, 1.0)
                signals.append(Signal(
                    score: avgScore,
                    weight: 0.20 * weight,
                    reason: "Your \(wineInfo.region) wines average \(String(format: "%.1f", avgScore))"
                ))
            }
        }

        // SIGNAL 3: Color match (weight scales with sample size like variety/region)
        let sameColor = ratedWines.filter { $0.color == wineInfo.color }
        if !sameColor.isEmpty {
            let avgScore = sameColor.reduce(0.0) { $0 + $1.score } / Double(sameColor.count)
            let countWeight = min(Double(sameColor.count) / 5.0, 1.0)
            signals.append(Signal(
                score: avgScore,
                weight: 0.15 * countWeight,
                reason: colorReason(avg: avgScore, color: wineInfo.color)
            ))
        }

        // SIGNAL 4: Body match (weight scales with sample size)
        let sameBody = ratedWines.filter { $0.body == wineInfo.body }
        if !sameBody.isEmpty {
            let avgScore = sameBody.reduce(0.0) { $0 + $1.score } / Double(sameBody.count)
            let countWeight = min(Double(sameBody.count) / 5.0, 1.0)
            signals.append(Signal(
                score: avgScore,
                weight: 0.10 * countWeight,
                reason: bodyReason(avg: avgScore, body: wineInfo.body)
            ))
        }

        // SIGNAL 5: Community signal (similar wines highly rated by other users)
        if !publicRatings.isEmpty {
            let communityMatches = publicRatings.filter { rating in
                (!wineInfo.variety.isEmpty && rating.variety.lowercased() == wineInfo.variety.lowercased()) ||
                (!wineInfo.region.isEmpty && rating.region.lowercased() == wineInfo.region.lowercased())
            }
            if !communityMatches.isEmpty {
                let avgCommunity = communityMatches.reduce(0.0) { $0 + $1.score } / Double(communityMatches.count)
                signals.append(Signal(
                    score: avgCommunity,
                    weight: 0.20,
                    reason: "The community rates similar wines \(String(format: "%.1f", avgCommunity))"
                ))
            }
        }

        // Combine signals
        guard !signals.isEmpty else {
            return WinePrediction(
                verdict: .unknown,
                confidence: 0,
                reasons: ["Not enough data yet about this style"]
            )
        }

        let totalWeight = signals.reduce(0.0) { $0 + $1.weight }
        let weightedScore = signals.reduce(0.0) { $0 + $1.score * $1.weight }
        let predictedScore = totalWeight > 0 ? weightedScore / totalWeight : 5.0
        // Scale down confidence when the evidence base is thin (quiz-only = max ~35%)
        let evidenceFactor = min(1.0, 0.35 + Double(ratedWines.count) / 12.0)
        let confidence = min(totalWeight / 0.7, 1.0) * evidenceFactor

        // Sort reasons by signal weight
        let topReasons = signals
            .sorted { $0.weight > $1.weight }
            .prefix(2)
            .map { $0.reason }

        return WinePrediction(
            verdict: verdictFor(score: predictedScore, confidence: confidence),
            confidence: confidence,
            reasons: Array(topReasons),
            predictedScore: predictedScore
        )
    }

    // MARK: - Quiz-based Signals

    /// As the user rates more wines, the quiz weight tapers off (real data beats stated preference)
    private func profileWeightFor(ratedCount: Int) -> Double {
        switch ratedCount {
        case 0: return 1.0       // quiz is everything
        case 1...5: return 0.7   // quiz still dominates
        case 6...15: return 0.4  // balanced
        case 16...30: return 0.2 // ratings dominate
        default: return 0.1      // quiz barely matters
        }
    }

    private func signalsFromTasteProfile(
        wineInfo: WineInfo,
        profile: TasteProfile,
        baseWeight: Double
    ) -> [Signal] {
        var signals: [Signal] = []

        // Color preference
        if !profile.preferredColors.isEmpty {
            if profile.preferredColors.contains(wineInfo.color) {
                signals.append(Signal(
                    score: 8.5,
                    weight: 0.25 * baseWeight,
                    reason: "You said you enjoy \(wineInfo.color.rawValue.lowercased()) wines"
                ))
            } else {
                signals.append(Signal(
                    score: 5.0,
                    weight: 0.25 * baseWeight,
                    reason: "Not one of your usual styles"
                ))
            }
        }

        // Body match
        if let preferredBody = profile.preferredBody {
            if preferredBody == wineInfo.body {
                signals.append(Signal(
                    score: 8.5,
                    weight: 0.20 * baseWeight,
                    reason: "Matches your \(preferredBody.rawValue.lowercased())-bodied preference"
                ))
            } else {
                signals.append(Signal(
                    score: 6.0,
                    weight: 0.15 * baseWeight,
                    reason: "Different body than you usually prefer"
                ))
            }
        }

        // Sweetness match
        if let preferredSweetness = profile.preferredSweetness {
            if preferredSweetness == wineInfo.sweetness {
                signals.append(Signal(
                    score: 8.5,
                    weight: 0.15 * baseWeight,
                    reason: "\(preferredSweetness.rawValue) — just how you like it"
                ))
            } else {
                signals.append(Signal(
                    score: 5.5,
                    weight: 0.15 * baseWeight,
                    reason: "Different sweetness level than your usual"
                ))
            }
        }

        // Variety match from quiz (diacritic-folded so OCR variants match quiz strings)
        if !profile.preferredVarieties.isEmpty, !wineInfo.variety.isEmpty {
            let fold: (String) -> String = {
                $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            }
            let foldedVariety = fold(wineInfo.variety)
            if profile.preferredVarieties.contains(where: { fold($0) == foldedVariety }) {
                signals.append(Signal(
                    score: 8.0,
                    weight: 0.30 * baseWeight,
                    reason: "You marked \(wineInfo.variety) as a favorite"
                ))
            }
        }

        // Region match from quiz (diacritic-folded; containment handles sub/super region pairs)
        if !profile.preferredRegions.isEmpty, !wineInfo.region.isEmpty {
            let fold: (String) -> String = {
                $0.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            }
            let foldedRegion = fold(wineInfo.region)
            if profile.preferredRegions.contains(where: {
                let f = fold($0)
                return f == foldedRegion || f.contains(foldedRegion) || foldedRegion.contains(f)
            }) {
                signals.append(Signal(
                    score: 8.0,
                    weight: 0.25 * baseWeight,
                    reason: "You marked \(wineInfo.region) as a favorite region"
                ))
            }
        }

        return signals
    }

    private func verdictFor(score: Double, confidence: Double) -> Verdict {
        // Low confidence overrides everything
        if confidence < 0.25 {
            return .uncertain
        }

        switch score {
        case 9...10: return .love
        case 8..<9: return .strongMatch
        case 7..<8: return .likely
        case 6..<7: return .maybe
        case 5..<6: return .meh
        default: return .skip
        }
    }

    private func colorReason(avg: Double, color: WineColor) -> String {
        let name = color.rawValue.lowercased()
        switch avg {
        case 7.5...: return "You generally enjoy \(name) wines (avg \(String(format: "%.1f", avg)))"
        case 5.5..<7.5: return "Your \(name) wines have been mixed (avg \(String(format: "%.1f", avg)))"
        default: return "\(color.rawValue) wines haven't been your thing (avg \(String(format: "%.1f", avg)))"
        }
    }

    private func bodyReason(avg: Double, body: WineBody) -> String {
        switch avg {
        case 7.5...: return "\(body.rawValue)-bodied wines suit you (avg \(String(format: "%.1f", avg)))"
        case 5.5..<7.5: return "\(body.rawValue)-bodied wines have been mixed for you"
        default: return "\(body.rawValue)-bodied wines haven't been your usual"
        }
    }

    private struct Signal {
        let score: Double
        let weight: Double
        let reason: String
    }
}

// MARK: - Prediction Result

struct WinePrediction {
    let verdict: Verdict
    let confidence: Double  // 0-1
    let reasons: [String]
    var predictedScore: Double? = nil
}

enum Verdict {
    case love           // 9+ predicted
    case strongMatch    // 8-9
    case likely         // 7-8
    case maybe          // 6-7
    case meh            // 5-6
    case skip           // < 5
    case uncertain      // low confidence
    case unknown        // not enough user data

    var headline: String {
        switch self {
        case .love:        return "You'll Love This"
        case .strongMatch: return "Right Up Your Alley"
        case .likely:      return "You'll Probably Enjoy It"
        case .maybe:       return "Worth a Try"
        case .meh:         return "Not Your Usual"
        case .skip:        return "Probably Skip"
        case .uncertain:   return "Hard to Say"
        case .unknown:     return "Unknown Territory"
        }
    }

    var subline: String {
        switch self {
        case .love:        return "An exceptional match for your taste"
        case .strongMatch: return "Matches your favorites closely"
        case .likely:      return "Aligns well with what you enjoy"
        case .maybe:       return "Different from your usual — could surprise you"
        case .meh:         return "Doesn't fit your typical preferences"
        case .skip:        return "Unlikely to suit your taste"
        case .uncertain:   return "Try it and let us learn"
        case .unknown:     return "Rate more wines for better predictions"
        }
    }

    var icon: String {
        switch self {
        case .love:        return "heart.fill"
        case .strongMatch: return "sparkles"
        case .likely:      return "hand.thumbsup.fill"
        case .maybe:       return "questionmark.circle.fill"
        case .meh:         return "minus.circle.fill"
        case .skip:        return "hand.thumbsdown.fill"
        case .uncertain:   return "questionmark.diamond.fill"
        case .unknown:     return "wineglass"
        }
    }

    /// Color hex name to use from WineTheme
    var color: VerdictColor {
        switch self {
        case .love, .strongMatch:  return .gold
        case .likely:              return .green
        case .maybe:               return .amber
        case .meh, .skip:          return .burgundy
        case .uncertain, .unknown: return .muted
        }
    }
}

enum VerdictColor {
    case gold
    case green
    case amber
    case burgundy
    case muted
}
