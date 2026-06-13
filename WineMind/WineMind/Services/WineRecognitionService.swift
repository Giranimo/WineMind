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

    func recognizeWine(from image: UIImage) async throws -> WineInfo {
        guard let cgImage = image.cgImage else {
            throw WineRecognitionError.invalidImage
        }
        let recognizedText = try await extractText(from: cgImage, orientation: image.imageOrientation)
        return parseWineLabel(from: recognizedText)
    }

    // MARK: - Wine Lexicon

    /// Prevents usesLanguageCorrection from mangling producer names and grape varieties.
    private static let wineCustomWords: [String] = {
        let hardcoded = [
            "Cabernet", "Sauvignon", "Pinot", "Noir", "Gris", "Grigio", "Merlot", "Syrah", "Shiraz",
            "Malbec", "Zinfandel", "Tempranillo", "Sangiovese", "Nebbiolo", "Grenache", "Mourvedre",
            "Mourvèdre", "Barbera", "Viognier", "Chardonnay", "Riesling", "Moscato", "Muscat",
            "Gewurztraminer", "Gewürztraminer", "Chenin", "Semillon", "Sémillon", "Albarino",
            "Albariño", "Verdejo", "Torrontes", "Torrontés", "Prosecco", "Corvina", "Touriga",
            "Nacional", "Glera", "Carmenere", "Carménère", "Tannat", "Pinotage", "Vermentino",
            "Fiano", "Primitivo", "Verdot", "Franc", "Petite", "Petit",
            "Napa", "Sonoma", "Bordeaux", "Burgundy", "Bourgogne", "Champagne", "Rhône", "Loire",
            "Alsace", "Languedoc", "Provence", "Tuscany", "Toscana", "Piedmont", "Piemonte",
            "Veneto", "Sicilia", "Rioja", "Mendoza", "Barossa", "Marlborough", "Stellenbosch",
            "Mosel", "Rheingau", "Douro", "Willamette", "Priorat", "Ribera", "Wachau",
            "Gigondas", "Pomerol", "Brunello", "Montalcino", "Chianti", "Classico",
            "Amarone", "Valpolicella", "Barolo", "Barbaresco",
        ]
        let catalogWords = WineCatalog.all
            .flatMap { [$0.winery, $0.name, $0.variety, $0.region] }
            .flatMap { $0.components(separatedBy: .whitespaces) }
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { $0.count > 2 }
        return Array(Set(hardcoded + catalogWords))
    }()

    // MARK: - Apple Vision OCR

    private func extractText(from cgImage: CGImage, orientation: UIImage.Orientation) async throws -> [String] {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let results = (request.results as? [VNRecognizedTextObservation]) ?? []
                // Sort top-to-bottom. Vision uses bottom-left origin so higher midY = higher on image.
                let sorted = results.sorted { $0.boundingBox.midY > $1.boundingBox.midY }
                let lines = sorted.compactMap { observation -> String? in
                    // Skip low-confidence observations (glare, foil, label edges)
                    let candidates = observation.topCandidates(3)
                    guard let best = candidates.first, best.confidence >= 0.3 else { return nil }
                    return best.string
                }
                continuation.resume(returning: lines)
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["en", "fr", "it", "es", "de", "pt"]
            request.usesLanguageCorrection = true
            request.customWords = WineRecognitionService.wineCustomWords
            request.minimumTextHeight = 0.015  // skip fine print below ~15pt
            if #available(iOS 16, *) {
                request.automaticallyDetectsLanguage = true
            }

            let handler = VNImageRequestHandler(
                cgImage: cgImage,
                orientation: CGImagePropertyOrientation(orientation),
                options: [:]
            )
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

        var (name, winery) = findNameAndWinery(lines: lines, variety: variety, region: region, vintage: vintage)

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
        // Lines with these words likely show a founding year, not a harvest vintage
        let foundingKeywords = ["since", "founded", "established", "est.", "©", "copyright", "distil"]

        for line in lines {
            let lower = line.lowercased()
            guard !foundingKeywords.contains(where: { lower.contains($0) }) else { continue }
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

    // MARK: - Word-boundary matching

    /// Matches `pattern` as a whole word, preventing substrings:
    /// "port" won't match "porto"; "rose" won't match "prose".
    private func wordBoundaryContains(_ text: String, _ pattern: String) -> Bool {
        let escaped = NSRegularExpression.escapedPattern(for: pattern)
        guard let regex = try? NSRegularExpression(pattern: "\\b\(escaped)\\b") else {
            return text.contains(pattern)
        }
        return regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    private func findVariety(in text: String) -> String {
        let varieties: [(String, String)] = [
            ("cabernet sauvignon", "Cabernet Sauvignon"),
            ("sauvignon blanc", "Sauvignon Blanc"),
            ("blanc de blancs", "Blanc de Blancs"),
            ("pinot grigio", "Pinot Grigio"),
            ("pinot gris", "Pinot Gris"),
            ("pinot noir", "Pinot Noir"),
            ("chenin blanc", "Chenin Blanc"),
            ("grüner veltliner", "Grüner Veltliner"),
            ("gruner veltliner", "Grüner Veltliner"),
            ("gewürztraminer", "Gewürztraminer"),
            ("gewurztraminer", "Gewürztraminer"),
            ("touriga nacional", "Touriga Nacional"),
            ("grenache blanc", "Grenache Blanc"),
            ("cabernet franc", "Cabernet Franc"),
            ("petite sirah", "Petite Sirah"),
            ("petit verdot", "Petit Verdot"),
            ("carménère", "Carménère"),
            ("carmenere", "Carménère"),
            ("mourvèdre", "Mourvèdre"),
            ("mourvedre", "Mourvèdre"),
            ("sémillon", "Sémillon"),
            ("semillon", "Sémillon"),
            ("albariño", "Albariño"),
            ("albarino", "Albariño"),
            ("torrontés", "Torrontés"),
            ("torrontes", "Torrontés"),
            ("merlot", "Merlot"),
            ("shiraz", "Shiraz"),
            ("malbec", "Malbec"),
            ("zinfandel", "Zinfandel"),
            ("tempranillo", "Tempranillo"),
            ("sangiovese", "Sangiovese"),
            ("nebbiolo", "Nebbiolo"),
            ("grenache", "Grenache"),
            ("barbera", "Barbera"),
            ("chardonnay", "Chardonnay"),
            ("riesling", "Riesling"),
            ("moscato", "Moscato"),
            ("muscat", "Muscat"),
            ("viognier", "Viognier"),
            ("verdejo", "Verdejo"),
            ("corvina", "Corvina"),
            ("primitivo", "Primitivo"),
            ("vermentino", "Vermentino"),
            ("pinotage", "Pinotage"),
            ("tannat", "Tannat"),
            ("fiano", "Fiano"),
            ("syrah", "Syrah"),
            ("glera", "Glera"),
            ("prosecco", "Prosecco"),
            ("champagne", "Champagne"),
            ("cava", "Cava"),
            ("rosé", "Rosé"),
            ("rose", "Rosé"),
            ("brut", "Brut"),
            ("port", "Port"),
            ("sherry", "Sherry"),
        ]

        // Match longest key first so multi-word names beat their components
        for (key, display) in varieties.sorted(by: { $0.0.count > $1.0.count }) {
            if wordBoundaryContains(text, key) { return display }
        }
        return ""
    }

    private func findRegion(in text: String) -> String {
        // Longer, more specific entries first so sub-regions match before parent regions
        let regions: [(String, String)] = [
            ("willamette valley", "Willamette Valley"),
            ("columbia valley", "Columbia Valley"),
            ("walla walla", "Walla Walla"),
            ("santa barbara", "Santa Barbara"),
            ("central coast", "Central Coast"),
            ("russian river valley", "Russian River Valley"),
            ("russian river", "Russian River Valley"),
            ("alexander valley", "Alexander Valley"),
            ("ribera del duero", "Ribera del Duero"),
            ("napa valley", "Napa Valley"),
            ("paso robles", "Paso Robles"),
            ("barossa valley", "Barossa Valley"),
            ("mclaren vale", "McLaren Vale"),
            ("margaret river", "Margaret River"),
            ("hunter valley", "Hunter Valley"),
            ("rías baixas", "Rías Baixas"),
            ("rias baixas", "Rías Baixas"),
            ("alto adige", "Alto Adige"),
            ("châteauneuf-du-pape", "Châteauneuf-du-Pape"),
            ("chateauneuf-du-pape", "Châteauneuf-du-Pape"),
            ("chateauneuf du pape", "Châteauneuf-du-Pape"),
            ("saint-émilion", "Saint-Émilion"),
            ("saint-emilion", "Saint-Émilion"),
            ("saint emilion", "Saint-Émilion"),
            ("haut-médoc", "Haut-Médoc"),
            ("haut-medoc", "Haut-Médoc"),
            ("haut medoc", "Haut-Médoc"),
            ("côtes du rhône", "Côtes du Rhône"),
            ("cotes du rhone", "Côtes du Rhône"),
            ("marlborough", "Marlborough"),
            ("stellenbosch", "Stellenbosch"),
            ("mendoza", "Mendoza"),
            ("bordeaux", "Bordeaux"),
            ("bourgogne", "Burgundy"),
            ("burgundy", "Burgundy"),
            ("champagne", "Champagne"),
            ("rhône", "Rhône Valley"),
            ("rhone", "Rhône Valley"),
            ("loire", "Loire Valley"),
            ("alsace", "Alsace"),
            ("languedoc", "Languedoc"),
            ("provence", "Provence"),
            ("toscana", "Tuscany"),
            ("tuscany", "Tuscany"),
            ("piemonte", "Piedmont"),
            ("piedmont", "Piedmont"),
            ("veneto", "Veneto"),
            ("sicilia", "Sicily"),
            ("sicily", "Sicily"),
            ("barossa", "Barossa Valley"),
            ("priorat", "Priorat"),
            ("rioja", "Rioja"),
            ("mosel", "Mosel"),
            ("rheingau", "Rheingau"),
            ("wachau", "Wachau"),
            ("douro", "Douro Valley"),
            ("pomerol", "Pomerol"),
            ("gigondas", "Gigondas"),
            ("sonoma", "Sonoma"),
            ("napa", "Napa Valley"),
        ]

        for (key, display) in regions {
            if wordBoundaryContains(text, key) { return display }
        }
        return ""
    }

    private func findNameAndWinery(lines: [String], variety: String, region: String, vintage: Int) -> (name: String, winery: String) {
        let vintageStr = "\(vintage)"
        let candidateLines = lines.filter { line in
            let lower = line.lowercased().trimmingCharacters(in: .whitespaces)
            let isVariety = !variety.isEmpty && lower == variety.lowercased()
            let isRegion = !region.isEmpty && lower == region.lowercased()
            let isVintage = lower == vintageStr
            let isTooShort = lower.count < 2
            let isBoilerplate = lower.contains("alcohol") || lower.contains("contains sulfites") ||
                lower.contains("750 ml") || (lower.contains("estate") && lower.count < 8)
            return !isVariety && !isRegion && !isVintage && !isTooShort && !isBoilerplate
        }

        let name = candidateLines.first ?? ""
        let winery = candidateLines.count > 1 ? candidateLines[1] : ""
        return (name, winery)
    }

    private func guessColor(variety: String, text: String) -> WineColor {
        let v = variety.lowercased()
        let reds = ["cabernet", "merlot", "pinot noir", "syrah", "shiraz", "malbec",
                    "zinfandel", "tempranillo", "sangiovese", "nebbiolo", "grenache",
                    "mourvedre", "mourvèdre", "barbera", "petite sirah", "petit verdot",
                    "corvina", "primitivo", "pinotage", "tannat", "carmenere", "carménère"]
        let whites = ["chardonnay", "sauvignon blanc", "riesling", "pinot grigio", "pinot gris",
                      "moscato", "gewurztraminer", "gewürztraminer", "viognier", "chenin blanc",
                      "semillon", "sémillon", "gruner veltliner", "grüner veltliner",
                      "albarino", "albariño", "verdejo", "torrontes", "torrontés",
                      "vermentino", "fiano", "glera"]
        let sparkling = ["prosecco", "champagne", "cava", "brut", "blanc de blancs"]

        if wordBoundaryContains(text, "rosé") || wordBoundaryContains(text, "rose") { return .rose }
        if sparkling.contains(where: { v.contains($0) }) { return .sparkling }
        if wordBoundaryContains(text, "port") || wordBoundaryContains(text, "sherry") ||
           text.contains("sauternes") || text.contains("dessert") { return .dessert }
        if whites.contains(where: { v.contains($0) }) { return .white }
        if reds.contains(where: { v.contains($0) }) { return .red }
        if text.contains("orange wine") { return .orange }
        return .red
    }

    private func guessBody(variety: String) -> WineBody {
        let v = variety.lowercased()
        let fullBody = ["cabernet sauvignon", "syrah", "shiraz", "malbec", "nebbiolo",
                        "petite sirah", "zinfandel", "tannat", "corvina", "primitivo", "pinotage"]
        let lightBody = ["pinot noir", "riesling", "pinot grigio", "pinot gris", "moscato",
                         "prosecco", "albarino", "albariño", "glera", "vermentino", "fiano"]

        if fullBody.contains(where: { v.contains($0) }) { return .full }
        if lightBody.contains(where: { v.contains($0) }) { return .light }
        return .medium
    }

    private func guessSweetness(variety: String, text: String) -> WineSweetness {
        let v = variety.lowercased()
        let sweetKeywords = ["sweet", "dessert", "sauternes", "spätlese", "auslese",
                             "beerenauslese", "trockenbeerenauslese", "eiswein"]
        let offDryKeywords = ["off-dry", "semi-sweet", "kabinett", "halbtrocken", "demi-sec"]

        if v.contains("moscato") || v.contains("port") ||
           sweetKeywords.contains(where: { text.contains($0) }) { return .sweet }
        if v.contains("riesling") || offDryKeywords.contains(where: { text.contains($0) }) { return .offDry }
        return .dry
    }
}

// MARK: - CGImagePropertyOrientation from UIImage.Orientation

extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up:            self = .up
        case .down:          self = .down
        case .left:          self = .left
        case .right:         self = .right
        case .upMirrored:    self = .upMirrored
        case .downMirrored:  self = .downMirrored
        case .leftMirrored:  self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default:    self = .up
        }
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
