import SwiftUI
import SwiftData

struct WineDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allWines: [Wine]
    @Bindable var wine: Wine
    @State private var similarWines: [WineRecommendation] = []

    private let engine = RecommendationEngine()

    var body: some View {
        ZStack {
            WineTheme.backgroundGradient.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // Hero photo
                    if let photo = wine.photo {
                        Image(uiImage: photo)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 360)
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .overlay {
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(WineTheme.gold.opacity(0.4), lineWidth: 1)
                            }
                            .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
                            .padding(.horizontal)
                    }

                    // Title & winery
                    VStack(spacing: 8) {
                        Text(wine.name.isEmpty ? "Unknown Wine" : wine.name)
                            .font(.wineTitle)
                            .foregroundStyle(WineTheme.cream)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        if !wine.winery.isEmpty {
                            Text(wine.winery)
                                .font(.wineSubheadline)
                                .italic()
                                .foregroundStyle(WineTheme.gold)
                        }
                    }

                    GoldDivider()
                        .padding(.horizontal, 40)

                    // Score
                    VStack(spacing: 6) {
                        Text(String(format: "%.1f", wine.score))
                            .font(.wineScore)
                            .foregroundStyle(WineTheme.scoreColor(wine.score))

                        Text(WineTheme.scoreLabel(wine.score))
                            .font(.wineCallout)
                            .italic()
                            .foregroundStyle(WineTheme.mutedText)
                    }

                    // Info chips
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        InfoCard(title: "Variety", value: wine.variety, icon: "leaf.fill")
                        InfoCard(title: "Region", value: wine.region, icon: "map.fill")
                        InfoCard(title: "Vintage", value: "\(wine.vintage)", icon: "calendar")
                        InfoCard(title: "Color", value: wine.color.rawValue, icon: wine.color.systemImage)
                        InfoCard(title: "Body", value: wine.body.rawValue, icon: "scalemass.fill")
                        InfoCard(title: "Sweetness", value: wine.sweetness.rawValue, icon: "drop.fill")
                    }
                    .padding(.horizontal)

                    // Tasting notes
                    if !wine.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "quote.opening")
                                    .foregroundStyle(WineTheme.gold)
                                Text("Tasting Notes")
                                    .font(.wineTitle3)
                                    .foregroundStyle(WineTheme.cream)
                            }

                            Text(wine.notes)
                                .font(.wineBody)
                                .foregroundStyle(WineTheme.cream.opacity(0.85))
                                .italic()
                                .lineSpacing(4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(WineTheme.cardGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal)
                    }

                    // Similar wines
                    if !similarWines.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundStyle(WineTheme.gold)
                                Text("Similar in Your Cellar")
                                    .font(.wineTitle3)
                                    .foregroundStyle(WineTheme.cream)
                            }
                            .padding(.horizontal)

                            ForEach(similarWines) { rec in
                                NavigationLink(destination: WineDetailView(wine: rec.wine)) {
                                    SimilarWineRow(recommendation: rec)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
                        }
                    }

                    Text("Added \(wine.dateAdded.formatted(date: .abbreviated, time: .omitted))")
                        .font(.wineCaption)
                        .foregroundStyle(WineTheme.dimText)
                        .padding(.top)
                }
                .padding(.vertical)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(WineTheme.background, for: .navigationBar)
        .onAppear {
            similarWines = engine.findSimilar(to: wine, in: allWines)
        }
    }
}

struct InfoCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(WineTheme.gold)

            Text(value.isEmpty ? "—" : value)
                .font(.wineBody.weight(.semibold))
                .foregroundStyle(WineTheme.cream)
                .lineLimit(1)

            Text(title.uppercased())
                .font(.system(size: 10, weight: .medium))
                .tracking(1.2)
                .foregroundStyle(WineTheme.dimText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(WineTheme.cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(WineTheme.divider, lineWidth: 0.5)
        }
    }
}

struct SimilarWineRow: View {
    let recommendation: WineRecommendation

    var body: some View {
        HStack(spacing: 12) {
            if let photo = recommendation.wine.photo {
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(WineTheme.surfaceElevated)
                    .frame(width: 50, height: 64)
                    .overlay {
                        Image(systemName: "wineglass")
                            .foregroundStyle(WineTheme.burgundy.opacity(0.5))
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.wine.name)
                    .font(.wineBody.weight(.semibold))
                    .foregroundStyle(WineTheme.cream)
                Text(recommendation.reason)
                    .font(.wineCaption)
                    .italic()
                    .foregroundStyle(WineTheme.mutedText)
                    .lineLimit(2)
            }

            Spacer()

            if recommendation.wine.score > 0 {
                Text(String(format: "%.1f", recommendation.wine.score))
                    .font(.wineScoreSmall)
                    .foregroundStyle(WineTheme.scoreColor(recommendation.wine.score))
            }
        }
        .padding(12)
        .background(WineTheme.cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
