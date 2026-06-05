import Foundation
import UIKit
import Vision

struct WineInfo {
    var name: String
    var winery: String
    var variety: String
    var region: String
    var vintage: Int
    var color: WineColor
    var body: WineBody
    var sweetness: WineSweetness
}

actor WineRecognitionService {

    /// Recognize wine details from a label photo using Apple Vision (free, on-device OCR)
    func recognizeWine(from image: UIImage) async throws -> WineInfo {
        guard let cgImage = image.cgImage else {
            throw WineRecognitionError.invalidImage
        }

        let recognizedText = try await extractText(from: cgImage)
        return parseWineLabel(from: recognizedText)
    }

    // MARK: - Apple Vision OCR

    private func extractText(from cgImage: CGImage) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let results = (request.results as? [VNRecognizedTextObservation]) ?? []
                let lines = results.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                continuation.resume(returning: lines)
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en", "fr", "it", "es", "de", "pt"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // MARK: - Smart Label Parsing

    private func parseWineLabel(from lines: [String]) -> WineInfo {
        let allText = lines.joined(separator: " ")
        let allTextLower = allText.lowercased()

        let vintage = findVintage(in: lines)
        var variety = findVariety(in: allTextLower)
        var region = findRegion(in: allTextLower)

        // The wine name is typically the most prominent text (first or second line)
        // The winery is usually near the top too
        var (name, winery) = findNameAndWinery(lines: lines, variety: variety, region: region, vintage: vintage)

        // Cross-reference the bundled catalog: if a known producer appears in the
        // OCR text, use that entry to fill any fields the heuristics missed.
        if let match = catalogMatch(in: allTextLower) {
            if winery.isEmpty { winery = match.winery }
            if variety.isEmpty { variety = match.variety }
            if region.isEmpty { region = match.region }
            if name.isEmpty { name = match.name }
        }

        let color = guessColor(variety: variety, text: allTextLower)
        let body = guessBody(variety: variety)
        let sweetness = guessSweetness(variety: variety, text: allTextLower)

        return WineInfo(
            name: name,
            winery: winery,
            variety: variety,
            region: region,
            vintage: vintage,
            color: color,
            body: body,
            sweetness: sweetness
        )
    }

    /// Match the OCR text against known producers in the bundled catalog,
    /// longest winery name first to avoid partial collisions.
    private func catalogMatch(in text: String) -> CatalogWine? {
        let byWineryLength = WineCatalog.all.sorted { $0.winery.count > $1.winery.count }
        for wine in byWineryLength where !wine.winery.isEmpty {
            if text.contains(wine.winery.lowercased()) { return wine }
        }
        return nil
    }

    private func findVintage(in lines: [String]) -> Int {
        let currentYear = Calendar.current.component(.year, from: Date())
        let yearPattern = try! NSRegularExpression(pattern: "\\b(19[5-9]\\d|20[0-2]\\d)\\b")

        for line in lines {
            let range = NSRange(line.startIndex..., in: line)
            if let match = yearPattern.firstMatch(in: line, range: range),
               let yearRange = Range(match.range(at: 1), in: line),
               let year = Int(line[yearRange]),
               year <= currentYear {
                return year
            }
        }
        return currentYear
    }

    private func findVariety(in text: String) -> String {
        let varieties = [
            "cabernet sauvignon": "Cabernet Sauvignon",
            "pinot noir": "Pinot Noir",
            "merlot": "Merlot",
            "syrah": "Syrah",
            "shiraz": "Shiraz",
            "malbec": "Malbec",
            "zinfandel": "Zinfandel",
            "tempranillo": "Tempranillo",
            "sangiovese": "Sangiovese",
            "nebbiolo": "Nebbiolo",
            "grenache": "Grenache",
            "mourvedre": "Mourvedre",
            "barbera": "Barbera",
            "petite sirah": "Petite Sirah",
            "petit verdot": "Petit Verdot",
            "cabernet franc": "Cabernet Franc",
            "pinot grigio": "Pinot Grigio",
            "pinot gris": "Pinot Gris",
            "chardonnay": "Chardonnay",
            "sauvignon blanc": "Sauvignon Blanc",
            "riesling": "Riesling",
            "moscato": "Moscato",
            "muscat": "Muscat",
            "gewurztraminer": "Gewurztraminer",
            "viognier": "Viognier",
            "chenin blanc": "Chenin Blanc",
            "semillon": "Semillon",
            "gruner veltliner": "Gruner Veltliner",
            "albarino": "Albarino",
            "verdejo": "Verdejo",
            "torrontes": "Torrontes",
            "prosecco": "Prosecco",
            "champagne": "Champagne",
            "cava": "Cava",
            "rose": "Rosé",
            "rosé": "Rosé",
            "blanc de blancs": "Blanc de Blancs",
            "brut": "Brut",
            "port": "Port",
            "sherry": "Sherry",
        ]

        // Match longest first (e.g. "cabernet sauvignon" before "cabernet")
        let sorted = varieties.keys.sorted { $0.count > $1.count }
        for key in sorted {
            if text.contains(key) {
                return varieties[key]!
            }
        }
        return ""
    }

    private func findRegion(in text: String) -> String {
        let regions = [
            "napa valley": "Napa Valley",
            "sonoma": "Sonoma",
            "paso robles": "Paso Robles",
            "willamette valley": "Willamette Valley",
            "columbia valley": "Columbia Valley",
            "walla walla": "Walla Walla",
            "santa barbara": "Santa Barbara",
            "central coast": "Central Coast",
            "russian river": "Russian River Valley",
            "alexander valley": "Alexander Valley",
            "bordeaux": "Bordeaux",
            "burgundy": "Burgundy",
            "bourgogne": "Burgundy",
            "champagne": "Champagne",
            "rhone": "Rhône Valley",
            "rhône": "Rhône Valley",
            "loire": "Loire Valley",
            "alsace": "Alsace",
            "languedoc": "Languedoc",
            "provence": "Provence",
            "tuscany": "Tuscany",
            "toscana": "Tuscany",
            "piedmont": "Piedmont",
            "piemonte": "Piedmont",
            "veneto": "Veneto",
            "sicilia": "Sicily",
            "rioja": "Rioja",
            "ribera del duero": "Ribera del Duero",
            "priorat": "Priorat",
            "mendoza": "Mendoza",
            "barossa valley": "Barossa Valley",
            "barossa": "Barossa Valley",
            "mclaren vale": "McLaren Vale",
            "marlborough": "Marlborough",
            "stellenbosch": "Stellenbosch",
            "mosel": "Mosel",
            "rheingau": "Rheingau",
            "douro": "Douro Valley",
            "hunter valley": "Hunter Valley",
            "margaret river": "Margaret River",
        ]

        let sorted = regions.keys.sorted { $0.count > $1.count }
        for key in sorted {
            if text.contains(key) {
                return regions[key]!
            }
        }
        return ""
    }

    private func findNameAndWinery(lines: [String], variety: String, region: String, vintage: Int) -> (name: String, winery: String) {
        // Filter out lines that are just the variety, region, vintage, or very short
        let vintageStr = "\(vintage)"
        let candidateLines = lines.filter { line in
            let lower = line.lowercased().trimmingCharacters(in: .whitespaces)
            let isVariety = !variety.isEmpty && lower == variety.lowercased()
            let isRegion = !region.isEmpty && lower == region.lowercased()
            let isVintage = lower == vintageStr
            let isTooShort = lower.count < 2
            let isBoilerplate = lower.contains("alcohol") || lower.contains("contains sulfites") ||
                lower.contains("750 ml") || lower.contains("estate") && lower.count < 8
            return !isVariety && !isRegion && !isVintage && !isTooShort && !isBoilerplate
        }

        // First candidate is usually the wine name or winery
        let name = candidateLines.first ?? ""
        let winery = candidateLines.count > 1 ? candidateLines[1] : ""

        return (name, winery)
    }

    private func guessColor(variety: String, text: String) -> WineColor {
        let v = variety.lowercased()

        let reds = ["cabernet", "merlot", "pinot noir", "syrah", "shiraz", "malbec",
                    "zinfandel", "tempranillo", "sangiovese", "nebbiolo", "grenache",
                    "mourvedre", "barbera", "petite sirah", "petit verdot"]
        let whites = ["chardonnay", "sauvignon blanc", "riesling", "pinot grigio",
                      "pinot gris", "moscato", "gewurztraminer", "viognier", "chenin blanc",
                      "semillon", "gruner veltliner", "albarino", "verdejo", "torrontes"]
        let sparkling = ["prosecco", "champagne", "cava", "brut", "blanc de blancs"]

        if text.contains("rosé") || text.contains("rose") && !text.contains("prose") { return .rose }
        if sparkling.contains(where: { v.contains($0) }) { return .sparkling }
        if text.contains("port") || text.contains("sherry") { return .dessert }
        if whites.contains(where: { v.contains($0) }) { return .white }
        if reds.contains(where: { v.contains($0) }) { return .red }

        // Default to red (most common)
        return .red
    }

    private func guessBody(variety: String) -> WineBody {
        let v = variety.lowercased()
        let fullBody = ["cabernet sauvignon", "syrah", "shiraz", "malbec", "nebbiolo", "petite sirah", "zinfandel"]
        let lightBody = ["pinot noir", "riesling", "pinot grigio", "moscato", "prosecco", "albarino"]

        if fullBody.contains(where: { v.contains($0) }) { return .full }
        if lightBody.contains(where: { v.contains($0) }) { return .light }
        return .medium
    }

    private func guessSweetness(variety: String, text: String) -> WineSweetness {
        let v = variety.lowercased()
        if v.contains("moscato") || v.contains("port") || text.contains("sweet") || text.contains("dessert") {
            return .sweet
        }
        if v.contains("riesling") || text.contains("off-dry") || text.contains("semi") {
            return .offDry
        }
        return .dry
    }
}

enum WineRecognitionError: LocalizedError {
    case invalidImage
    case ocrFailed
    case parseError

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Could not process the image"
        case .ocrFailed: return "Could not read text from the label"
        case .parseError: return "Could not identify wine details from the label"
        }
    }
}
