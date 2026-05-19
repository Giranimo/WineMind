import SwiftUI

/// Dark, elegant wine cellar theme — burgundy & gold on deep charcoal
enum WineTheme {

    // MARK: - Colors

    /// Deep charcoal background — the cellar
    static let background = Color(red: 0.07, green: 0.05, blue: 0.06)

    /// Slightly lifted surface for cards
    static let surface = Color(red: 0.11, green: 0.08, blue: 0.10)

    /// Elevated surface for emphasized cards
    static let surfaceElevated = Color(red: 0.15, green: 0.11, blue: 0.13)

    /// Primary brand — deep burgundy
    static let burgundy = Color(red: 0.45, green: 0.10, blue: 0.18)

    /// Lighter burgundy for hover/highlights
    static let burgundyLight = Color(red: 0.62, green: 0.18, blue: 0.28)

    /// Bordeaux red for buttons
    static let bordeaux = Color(red: 0.55, green: 0.12, blue: 0.20)

    /// Gold accent — labels, scores, highlights
    static let gold = Color(red: 0.83, green: 0.69, blue: 0.42)

    /// Champagne — softer gold for subtle accents
    static let champagne = Color(red: 0.95, green: 0.87, blue: 0.71)

    /// Cream — primary text on dark
    static let cream = Color(red: 0.96, green: 0.93, blue: 0.88)

    /// Muted text
    static let mutedText = Color(red: 0.68, green: 0.62, blue: 0.58)

    /// Dimmed text
    static let dimText = Color(red: 0.48, green: 0.44, blue: 0.42)

    /// Divider lines
    static let divider = Color(red: 0.22, green: 0.18, blue: 0.20)

    // Score colors
    static let scoreOutstanding = Color(red: 0.83, green: 0.69, blue: 0.42)  // gold
    static let scoreExcellent = Color(red: 0.62, green: 0.78, blue: 0.55)    // sage
    static let scoreGood = Color(red: 0.85, green: 0.60, blue: 0.35)         // amber
    static let scorePoor = Color(red: 0.70, green: 0.30, blue: 0.30)         // muted red

    // MARK: - Gradients

    static let backgroundGradient = LinearGradient(
        colors: [
            background,
            Color(red: 0.10, green: 0.07, blue: 0.08)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    static let cardGradient = LinearGradient(
        colors: [
            surfaceElevated,
            surface
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let burgundyGradient = LinearGradient(
        colors: [bordeaux, burgundy],
        startPoint: .top,
        endPoint: .bottom
    )

    static let goldGradient = LinearGradient(
        colors: [champagne, gold],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Score Color Helper

    static func scoreColor(_ score: Double) -> Color {
        switch score {
        case 9...10: return scoreOutstanding
        case 7..<9: return scoreExcellent
        case 5..<7: return scoreGood
        default: return scorePoor
        }
    }

    static func scoreLabel(_ score: Double) -> String {
        switch score {
        case 9.5...10: return "Exceptional"
        case 9..<9.5: return "Outstanding"
        case 8..<9: return "Excellent"
        case 7..<8: return "Very Good"
        case 6..<7: return "Good"
        case 5..<6: return "Decent"
        case 3..<5: return "Below Average"
        default: return "Poor"
        }
    }
}

// MARK: - Typography

extension Font {
    /// Serif display font for titles
    static let wineDisplay = Font.system(.largeTitle, design: .serif).weight(.bold)
    static let wineTitle = Font.system(.title, design: .serif).weight(.semibold)
    static let wineTitle2 = Font.system(.title2, design: .serif).weight(.semibold)
    static let wineTitle3 = Font.system(.title3, design: .serif)

    /// Sans-serif body
    static let wineBody = Font.system(.body, design: .default)
    static let wineCallout = Font.system(.callout, design: .default)
    static let wineSubheadline = Font.system(.subheadline, design: .default)
    static let wineCaption = Font.system(.caption, design: .default)

    /// Score font — large serif numerals
    static let wineScore = Font.system(size: 64, weight: .bold, design: .serif)
    static let wineScoreSmall = Font.system(size: 22, weight: .bold, design: .serif)
}

// MARK: - View Modifiers

struct WineCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(WineTheme.cardGradient)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(WineTheme.divider, lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

struct GoldBorderStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(WineTheme.gold.opacity(0.6), lineWidth: 1)
            }
    }
}

extension View {
    func wineCard() -> some View { modifier(WineCardStyle()) }
    func goldBorder() -> some View { modifier(GoldBorderStyle()) }
}

// MARK: - Custom Components

struct GoldDivider: View {
    var body: some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(WineTheme.gold.opacity(0.3))
                .frame(height: 0.5)
            Image(systemName: "diamond.fill")
                .font(.system(size: 6))
                .foregroundStyle(WineTheme.gold.opacity(0.6))
            Rectangle()
                .fill(WineTheme.gold.opacity(0.3))
                .frame(height: 0.5)
        }
    }
}

struct WineButtonStyle: ButtonStyle {
    var prominent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.wineBody.weight(.semibold))
            .foregroundStyle(prominent ? WineTheme.cream : WineTheme.gold)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background {
                if prominent {
                    WineTheme.burgundyGradient
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    Color.clear
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(WineTheme.gold.opacity(0.6), lineWidth: 1)
                        }
                }
            }
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
