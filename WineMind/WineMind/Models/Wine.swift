import Foundation
import SwiftData
import UIKit

@Model
final class Wine {
    var id: UUID
    var name: String
    var winery: String
    var variety: String
    var region: String
    var vintage: Int
    var score: Double
    var notes: String

    @Attribute(.externalStorage)
    var photoData: Data?

    var dateAdded: Date
    var color: WineColor
    var body: WineBody
    var sweetness: WineSweetness

    var photo: UIImage? {
        guard let data = photoData else { return nil }
        return UIImage(data: data)
    }

    init(
        name: String = "",
        winery: String = "",
        variety: String = "",
        region: String = "",
        vintage: Int = Calendar.current.component(.year, from: Date()),
        score: Double = 0,
        notes: String = "",
        photoData: Data? = nil,
        color: WineColor = .red,
        body: WineBody = .medium,
        sweetness: WineSweetness = .dry
    ) {
        self.id = UUID()
        self.name = name
        self.winery = winery
        self.variety = variety
        self.region = region
        self.vintage = vintage
        self.score = score
        self.notes = notes
        self.photoData = photoData
        self.dateAdded = Date()
        self.color = color
        self.body = body
        self.sweetness = sweetness
    }
}

enum WineColor: String, Codable, CaseIterable {
    case red = "Red"
    case white = "White"
    case rose = "Rosé"
    case sparkling = "Sparkling"
    case dessert = "Dessert"
    case orange = "Orange"

    var systemImage: String {
        switch self {
        case .red: return "drop.fill"
        case .white: return "drop"
        case .rose: return "drop.halffull"
        case .sparkling: return "bubbles.and.sparkles"
        case .dessert: return "birthday.cake"
        case .orange: return "drop.degreesign"
        }
    }

    var displayColor: String {
        switch self {
        case .red: return "red"
        case .white: return "yellow"
        case .rose: return "pink"
        case .sparkling: return "mint"
        case .dessert: return "orange"
        case .orange: return "orange"
        }
    }
}

enum WineBody: String, Codable, CaseIterable {
    case light = "Light"
    case medium = "Medium"
    case full = "Full"
}

enum WineSweetness: String, Codable, CaseIterable {
    case dry = "Dry"
    case offDry = "Off-Dry"
    case sweet = "Sweet"
}
