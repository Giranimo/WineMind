import Foundation
import SwiftUI

/// User's taste profile from the calibration quiz — seeds predictions before they've rated wines
struct TasteProfile: Codable, Equatable {
    var preferredColors: Set<WineColor>
    var preferredBody: WineBody?
    var preferredSweetness: WineSweetness?
    var preferredFlavors: Set<FlavorProfile>
    var preferredVarieties: Set<String>
    var preferredRegions: Set<String>
    var experience: WineExperience

    var isComplete: Bool {
        !preferredColors.isEmpty && preferredBody != nil && preferredSweetness != nil
    }

    static let empty = TasteProfile(
        preferredColors: [],
        preferredBody: nil,
        preferredSweetness: nil,
        preferredFlavors: [],
        preferredVarieties: [],
        preferredRegions: [],
        experience: .casual
    )
}

enum FlavorProfile: String, Codable, CaseIterable, Hashable {
    case fruity = "Fruity"
    case earthy = "Earthy & savory"
    case oaky = "Oaky & vanilla"
    case bright = "Bright & citrus"
    case floral = "Floral & delicate"
    case spicy = "Bold & spicy"

    var icon: String {
        switch self {
        case .fruity: return "leaf.fill"
        case .earthy: return "mountain.2.fill"
        case .oaky: return "tree.fill"
        case .bright: return "sun.max.fill"
        case .floral: return "camera.macro"
        case .spicy: return "flame.fill"
        }
    }
}

enum WineExperience: String, Codable, CaseIterable {
    case beginner = "Just starting out"
    case casual = "Casual drinker"
    case enthusiast = "Wine enthusiast"
    case expert = "Sommelier-level"

    var icon: String {
        switch self {
        case .beginner: return "sparkles"
        case .casual: return "wineglass"
        case .enthusiast: return "star.fill"
        case .expert: return "crown.fill"
        }
    }
}

// MARK: - Storage

@MainActor
final class TasteProfileStore: ObservableObject {
    static let shared = TasteProfileStore()

    @Published var profile: TasteProfile = .empty
    @Published var hasCompletedQuiz: Bool = false

    private let profileKey = "winemind.tasteProfile"
    private let completedKey = "winemind.quizCompleted"

    init() {
        load()
    }

    func load() {
        if let data = UserDefaults.standard.data(forKey: profileKey),
           let decoded = try? JSONDecoder().decode(TasteProfile.self, from: data) {
            profile = decoded
        }
        hasCompletedQuiz = UserDefaults.standard.bool(forKey: completedKey)
    }

    func save(_ profile: TasteProfile) {
        self.profile = profile
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: profileKey)
        }
        hasCompletedQuiz = true
        UserDefaults.standard.set(true, forKey: completedKey)
    }

    func reset() {
        profile = .empty
        hasCompletedQuiz = false
        UserDefaults.standard.removeObject(forKey: profileKey)
        UserDefaults.standard.removeObject(forKey: completedKey)
    }
}
