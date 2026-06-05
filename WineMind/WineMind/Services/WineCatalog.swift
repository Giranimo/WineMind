import Foundation

/// A small bundled catalog of well-known wines that powers "You Might Like"
/// discovery — suggestions of bottles the user does NOT already own, matched to
/// their taste. Without this the app could only recommend community ratings
/// (empty until other users contribute) or the user's own cellar.
struct CatalogWine: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let winery: String
    let variety: String
    let region: String
    let vintage: Int
    let color: WineColor
    let body: WineBody
    let sweetness: WineSweetness
}

enum WineCatalog {
    static let all: [CatalogWine] = [
        CatalogWine(name: "Special Selection Cabernet", winery: "Caymus", variety: "Cabernet Sauvignon", region: "Napa Valley", vintage: 2019, color: .red, body: .full, sweetness: .dry),
        CatalogWine(name: "Estate Cabernet Sauvignon", winery: "Silver Oak", variety: "Cabernet Sauvignon", region: "Napa Valley", vintage: 2018, color: .red, body: .full, sweetness: .dry),
        CatalogWine(name: "Unico", winery: "Vega Sicilia", variety: "Tempranillo", region: "Ribera del Duero", vintage: 2012, color: .red, body: .full, sweetness: .dry),
        CatalogWine(name: "Gran Reserva", winery: "La Rioja Alta", variety: "Tempranillo", region: "Rioja", vintage: 2015, color: .red, body: .medium, sweetness: .dry),
        CatalogWine(name: "Brunello di Montalcino", winery: "Biondi-Santi", variety: "Sangiovese", region: "Tuscany", vintage: 2016, color: .red, body: .full, sweetness: .dry),
        CatalogWine(name: "Chianti Classico Riserva", winery: "Antinori", variety: "Sangiovese", region: "Tuscany", vintage: 2019, color: .red, body: .medium, sweetness: .dry),
        CatalogWine(name: "Barolo", winery: "Pio Cesare", variety: "Nebbiolo", region: "Piedmont", vintage: 2018, color: .red, body: .full, sweetness: .dry),
        CatalogWine(name: "Gevrey-Chambertin", winery: "Domaine Drouhin", variety: "Pinot Noir", region: "Burgundy", vintage: 2019, color: .red, body: .medium, sweetness: .dry),
        CatalogWine(name: "Willamette Pinot Noir", winery: "Domaine Serene", variety: "Pinot Noir", region: "Willamette Valley", vintage: 2020, color: .red, body: .medium, sweetness: .dry),
        CatalogWine(name: "Estate Malbec", winery: "Catena Zapata", variety: "Malbec", region: "Mendoza", vintage: 2020, color: .red, body: .full, sweetness: .dry),
        CatalogWine(name: "Côtes du Rhône", winery: "Guigal", variety: "Syrah", region: "Rhône Valley", vintage: 2020, color: .red, body: .medium, sweetness: .dry),
        CatalogWine(name: "Barossa Shiraz", winery: "Penfolds", variety: "Syrah", region: "Barossa Valley", vintage: 2019, color: .red, body: .full, sweetness: .dry),
        CatalogWine(name: "Château Margaux", winery: "Château Margaux", variety: "Cabernet Sauvignon", region: "Bordeaux", vintage: 2016, color: .red, body: .full, sweetness: .dry),
        CatalogWine(name: "Merlot", winery: "Duckhorn", variety: "Merlot", region: "Napa Valley", vintage: 2019, color: .red, body: .medium, sweetness: .dry),
        CatalogWine(name: "Amarone della Valpolicella", winery: "Allegrini", variety: "Corvina", region: "Veneto", vintage: 2017, color: .red, body: .full, sweetness: .offDry),
        CatalogWine(name: "Cuvée Brut", winery: "Veuve Clicquot", variety: "Champagne", region: "Champagne", vintage: 2018, color: .sparkling, body: .light, sweetness: .dry),
        CatalogWine(name: "Prosecco Superiore", winery: "Nino Franco", variety: "Glera", region: "Veneto", vintage: 2022, color: .sparkling, body: .light, sweetness: .offDry),
        CatalogWine(name: "Montrachet Grand Cru", winery: "Louis Latour", variety: "Chardonnay", region: "Burgundy", vintage: 2020, color: .white, body: .full, sweetness: .dry),
        CatalogWine(name: "Russian River Chardonnay", winery: "Kistler", variety: "Chardonnay", region: "Sonoma", vintage: 2021, color: .white, body: .medium, sweetness: .dry),
        CatalogWine(name: "Sancerre", winery: "Henri Bourgeois", variety: "Sauvignon Blanc", region: "Loire Valley", vintage: 2022, color: .white, body: .light, sweetness: .dry),
        CatalogWine(name: "Marlborough Sauvignon Blanc", winery: "Cloudy Bay", variety: "Sauvignon Blanc", region: "Marlborough", vintage: 2022, color: .white, body: .light, sweetness: .dry),
        CatalogWine(name: "Kabinett Riesling", winery: "Dr. Loosen", variety: "Riesling", region: "Mosel", vintage: 2021, color: .white, body: .light, sweetness: .offDry),
        CatalogWine(name: "Pinot Grigio", winery: "Santa Margherita", variety: "Pinot Grigio", region: "Alto Adige", vintage: 2022, color: .white, body: .light, sweetness: .dry),
        CatalogWine(name: "Albariño", winery: "Martín Códax", variety: "Albariño", region: "Rías Baixas", vintage: 2022, color: .white, body: .light, sweetness: .dry),
        CatalogWine(name: "Provence Rosé", winery: "Whispering Angel", variety: "Grenache", region: "Provence", vintage: 2022, color: .rose, body: .light, sweetness: .dry),
        CatalogWine(name: "Tavel Rosé", winery: "Château d'Aquéria", variety: "Grenache", region: "Rhône Valley", vintage: 2022, color: .rose, body: .medium, sweetness: .dry),
        CatalogWine(name: "Sauternes", winery: "Château d'Yquem", variety: "Sémillon", region: "Bordeaux", vintage: 2017, color: .dessert, body: .full, sweetness: .sweet),
        CatalogWine(name: "Vintage Port", winery: "Taylor's", variety: "Touriga Nacional", region: "Douro", vintage: 2016, color: .dessert, body: .full, sweetness: .sweet),
        CatalogWine(name: "Riesling Spätlese", winery: "Egon Müller", variety: "Riesling", region: "Mosel", vintage: 2019, color: .white, body: .medium, sweetness: .sweet),
        CatalogWine(name: "Ribera Crianza", winery: "Emilio Moro", variety: "Tempranillo", region: "Ribera del Duero", vintage: 2019, color: .red, body: .medium, sweetness: .dry),
        CatalogWine(name: "Napa Zinfandel", winery: "Ridge", variety: "Zinfandel", region: "Napa Valley", vintage: 2020, color: .red, body: .full, sweetness: .dry),
        CatalogWine(name: "Grüner Veltliner", winery: "Domäne Wachau", variety: "Grüner Veltliner", region: "Wachau", vintage: 2022, color: .white, body: .light, sweetness: .dry)
    ]

    /// Catalog wines the user doesn't own yet, ranked by how well they match the
    /// taste signals from the user's highly-rated wines. Always returns up to
    /// `limit` suggestions (even with weak matches) so Discover is never empty.
    static func discoveries(notIn wines: [Wine], limit: Int = 8) -> [CatalogWine] {
        let liked = wines.filter { $0.score >= 7.0 }
        let likedVarieties = Set(liked.map { $0.variety.lowercased() }.filter { !$0.isEmpty })
        let likedRegions = Set(liked.map { $0.region.lowercased() }.filter { !$0.isEmpty })
        let likedColors = Set(liked.map { $0.color })
        let likedBodies = Set(liked.map { $0.body })
        let likedSweetness = Set(liked.map { $0.sweetness })
        let owned = Set(wines.map { signature(name: $0.name, winery: $0.winery, vintage: $0.vintage) })

        return all
            .filter { !owned.contains(signature(name: $0.name, winery: $0.winery, vintage: $0.vintage)) }
            .map { wine -> (wine: CatalogWine, score: Int) in
                var score = 0
                if likedVarieties.contains(wine.variety.lowercased()) { score += 3 }
                if likedRegions.contains(wine.region.lowercased()) { score += 2 }
                if likedColors.contains(wine.color) { score += 2 }
                if likedBodies.contains(wine.body) { score += 1 }
                if likedSweetness.contains(wine.sweetness) { score += 1 }
                return (wine, score)
            }
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0.wine }
    }

    private static func signature(name: String, winery: String, vintage: Int) -> String {
        let n = name.lowercased().filter { $0.isLetter || $0.isNumber }
        let w = winery.lowercased().filter { $0.isLetter || $0.isNumber }
        return "\(w)-\(n)-\(vintage)"
    }

    /// Offline tasting-note suggestions to pre-fill the notes field when a wine is
    /// scanned. The app has no backend / wine API by design, so these are typical
    /// descriptors by grape variety (with a color fallback), meant as an editable
    /// starting point — not a live per-bottle lookup.
    static func suggestedNotes(variety: String, color: WineColor) -> String {
        let byVariety: [String: String] = [
            "cabernet sauvignon": "Blackcurrant, cedar, and dark plum with firm tannins and a long, structured finish.",
            "merlot": "Soft and round — ripe plum, black cherry, and cocoa with gentle tannins.",
            "pinot noir": "Red cherry, raspberry, and forest floor with bright acidity and a silky texture.",
            "syrah": "Blackberry, black pepper, and smoked meat with a bold, savory finish.",
            "shiraz": "Blackberry, black pepper, and smoked meat with a bold, savory finish.",
            "malbec": "Juicy blackberry and plum with violet notes and a velvety mouthfeel.",
            "tempranillo": "Cherry, leather, and dried fig with vanilla and spice from oak aging.",
            "sangiovese": "Tart cherry, dried herbs, and leather with bright acidity and grippy tannins.",
            "nebbiolo": "Rose, tar, and red cherry — high acid and tannin with great aging potential.",
            "zinfandel": "Jammy blackberry and raspberry with black pepper and sweet baking spice.",
            "corvina": "Dried cherry, fig, and chocolate — rich and warming.",
            "chardonnay": "Apple, pear, and citrus with butter, vanilla, and toasted oak.",
            "sauvignon blanc": "Crisp grapefruit, gooseberry, and fresh-cut grass with zesty acidity.",
            "riesling": "Lime, green apple, and honeysuckle with vibrant acidity.",
            "pinot grigio": "Light and crisp — lemon, green apple, and a clean mineral finish.",
            "albariño": "Citrus, white peach, and saline minerality with refreshing acidity.",
            "champagne": "Green apple, brioche, and citrus with fine, persistent bubbles.",
            "glera": "Pear, white flowers, and green apple — light, frothy, and refreshing.",
            "grenache": "Strawberry, white pepper, and dried herbs; delicate and fresh.",
            "grüner veltliner": "Green apple, white pepper, and citrus with crisp acidity.",
            "sémillon": "Honey, apricot, and beeswax — rich and luscious with bright acidity.",
            "touriga nacional": "Blackberry, violet, and dark chocolate — rich and sweet."
        ]
        if let notes = byVariety[variety.lowercased()] { return notes }
        switch color {
        case .red: return "Red and dark fruit with soft spice and a smooth, dry finish."
        case .white: return "Crisp orchard fruit and citrus with refreshing acidity."
        case .rose: return "Fresh strawberry and citrus with a light, dry finish."
        case .sparkling: return "Bright citrus and green apple with lively bubbles."
        case .dessert: return "Rich honeyed stone fruit with a sweet, lingering finish."
        case .orange: return "Dried apricot, tea, and citrus peel with grippy texture."
        }
    }
}
