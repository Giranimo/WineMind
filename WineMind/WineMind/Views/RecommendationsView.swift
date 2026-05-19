import SwiftUI
import SwiftData

struct RecommendationsView: View {
    @Query private var wines: [Wine]
    @EnvironmentObject var recommender: CollaborativeRecommender
    @State private var localRecommendations: [WineRecommendation] = []

    private let engine = RecommendationEngine()

    var topWines: [Wine] {
        wines
            .filter { $0.score >= 7.0 }
            .sorted { $0.score > $1.score }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                WineTheme.backgroundGradient.ignoresSafeArea()

                if wines.count < 3 {
                    notEnoughData
                } else if topWines.isEmpty {
                    noHighScores
                } else {
                    recommendationContent
                }
            }
            .navigationTitle("Discover")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await refreshAll() }
                    } label: {
                        if recommender.isLoading {
                            ProgressView()
                                .tint(WineTheme.gold)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .foregroundStyle(WineTheme.gold)
                        }
                    }
                    .disabled(recommender.isLoading)
                }
            }
            .task {
                await refreshAll()
            }
            .onChange(of: wines.count) { _, _ in
                refreshLocal()
            }
        }
    }

    private var notEnoughData: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "wineglass")
                .font(.system(size: 80))
                .foregroundStyle(WineTheme.burgundy.opacity(0.5))
            VStack(spacing: 8) {
                Text("Building Your Profile")
                    .font(.wineTitle2)
                    .foregroundStyle(WineTheme.cream)
                Text("Rate at least 3 wines so we can\nlearn what you love")
                    .font(.wineCallout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(WineTheme.mutedText)
            }
            Spacer()
        }
        .padding()
    }

    private var noHighScores: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "star")
                .font(.system(size: 80))
                .foregroundStyle(WineTheme.gold.opacity(0.5))
            VStack(spacing: 8) {
                Text("Find Your Favorites")
                    .font(.wineTitle2)
                    .foregroundStyle(WineTheme.cream)
                Text("Rate a few wines 7 or higher\nto get personalized picks")
                    .font(.wineCallout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(WineTheme.mutedText)
            }
            Spacer()
        }
        .padding()
    }

    private var recommendationContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                tasteProfile

                topWinesSection

                if !recommender.publicRecommendations.isEmpty {
                    communityRecommendations
                }

                if !localRecommendations.isEmpty {
                    fromYourCellar
                }

                Spacer().frame(height: 20)
            }
            .padding(.vertical)
        }
    }

    // MARK: - Sections

    private var tasteProfile: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Your Profile", icon: "person.crop.circle")

            let likedWines = wines.filter { $0.score >= 7.0 }
            let colorCounts = Dictionary(grouping: likedWines, by: \.color)
                .mapValues { $0.count }
                .sorted { $0.value > $1.value }
            let varietyCounts = Dictionary(grouping: likedWines.filter { !$0.variety.isEmpty }, by: { $0.variety.lowercased() })
                .mapValues { $0.count }
                .sorted { $0.value > $1.value }
            let regionCounts = Dictionary(grouping: likedWines.filter { !$0.region.isEmpty }, by: { $0.region })
                .mapValues { $0.count }
                .sorted { $0.value > $1.value }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    if let topColor = colorCounts.first {
                        ProfileChip(label: topColor.key.rawValue, icon: topColor.key.systemImage)
                    }
                    if let topVariety = varietyCounts.first {
                        ProfileChip(label: topVariety.key.capitalized, icon: "leaf.fill")
                    }
                    if let topRegion = regionCounts.first {
                        ProfileChip(label: topRegion.key, icon: "map.fill")
                    }
                    let avgScore = likedWines.isEmpty ? 0.0 : likedWines.reduce(0.0) { $0 + $1.score } / Double(likedWines.count)
                    ProfileChip(label: String(format: "Avg %.1f", avgScore), icon: "star.fill")
                }
                .padding(.horizontal)
            }
        }
    }

    private var topWinesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Your Top Bottles", icon: "crown.fill")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(topWines) { wine in
                        NavigationLink(destination: WineDetailView(wine: wine)) {
                            TopWineCard(wine: wine)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private var communityRecommendations: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("From the Community", icon: "person.3.fill")

            VStack(spacing: 12) {
                ForEach(recommender.publicRecommendations.prefix(10)) { rec in
                    CommunityRecommendationRow(recommendation: rec)
                        .padding(.horizontal)
                }
            }
        }
    }

    private var fromYourCellar: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Worth Revisiting", icon: "arrow.clockwise.circle.fill")

            VStack(spacing: 12) {
                ForEach(localRecommendations.filter { $0.wine.score < 7.0 }.prefix(5)) { rec in
                    NavigationLink(destination: WineDetailView(wine: rec.wine)) {
                        LocalRecommendationRow(recommendation: rec)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
            }
        }
    }

    private func sectionHeader(_ text: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(WineTheme.gold)
            Text(text)
                .font(.wineTitle3)
                .foregroundStyle(WineTheme.cream)
            Spacer()
        }
        .padding(.horizontal)
    }

    private func refreshAll() async {
        refreshLocal()
        await recommender.refreshRecommendations(from: wines)
    }

    private func refreshLocal() {
        localRecommendations = engine.getRecommendations(from: wines)
    }
}

// MARK: - Card Components

struct TopWineCard: View {
    let wine: Wine

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                if let photo = wine.photo {
                    Image(uiImage: photo)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 160, height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(WineTheme.surfaceElevated)
                        .frame(width: 160, height: 220)
                        .overlay {
                            Image(systemName: "wineglass")
                                .font(.system(size: 56))
                                .foregroundStyle(WineTheme.burgundy.opacity(0.5))
                        }
                }

                // Score badge overlay top right
                VStack {
                    HStack {
                        Spacer()
                        Text(String(format: "%.1f", wine.score))
                            .font(.wineScoreSmall)
                            .foregroundStyle(WineTheme.cream)
                            .padding(8)
                            .background(WineTheme.scoreColor(wine.score).opacity(0.9))
                            .clipShape(Circle())
                            .padding(8)
                    }
                    Spacer()
                }
                .frame(width: 160, height: 220)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(WineTheme.gold.opacity(0.3), lineWidth: 0.5)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(wine.name)
                    .font(.wineBody.weight(.semibold))
                    .foregroundStyle(WineTheme.cream)
                    .lineLimit(1)
                Text(wine.variety.isEmpty ? wine.winery : wine.variety)
                    .font(.wineCaption)
                    .italic()
                    .foregroundStyle(WineTheme.gold)
                    .lineLimit(1)
            }
        }
        .frame(width: 160)
    }
}

struct CommunityRecommendationRow: View {
    let recommendation: PublicRecommendation

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(WineTheme.burgundyGradient)
                    .frame(width: 56, height: 72)
                Image(systemName: "wineglass.fill")
                    .font(.title2)
                    .foregroundStyle(WineTheme.champagne)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.rating.wineName)
                    .font(.wineBody.weight(.semibold))
                    .foregroundStyle(WineTheme.cream)
                    .lineLimit(1)

                if !recommendation.rating.winery.isEmpty {
                    Text(recommendation.rating.winery)
                        .font(.wineCaption)
                        .italic()
                        .foregroundStyle(WineTheme.gold)
                        .lineLimit(1)
                }

                HStack(spacing: 6) {
                    Image(systemName: recommendation.source.icon)
                        .font(.system(size: 10))
                    Text(recommendation.reason)
                        .font(.wineCaption)
                        .lineLimit(2)
                }
                .foregroundStyle(WineTheme.mutedText)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(String(format: "%.1f", recommendation.rating.score))
                    .font(.wineScoreSmall)
                    .foregroundStyle(WineTheme.scoreColor(recommendation.rating.score))
                Text(recommendation.source.label.uppercased())
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(1)
                    .foregroundStyle(WineTheme.dimText)
            }
        }
        .padding(12)
        .background(WineTheme.cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(WineTheme.divider, lineWidth: 0.5)
        }
    }
}

struct LocalRecommendationRow: View {
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

            Text(String(format: "%d%%", Int(recommendation.score * 100)))
                .font(.wineCaption.bold())
                .foregroundStyle(WineTheme.gold)
        }
        .padding(12)
        .background(WineTheme.cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ProfileChip: View {
    let label: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(WineTheme.gold)
            Text(label)
                .font(.wineCaption.bold())
                .foregroundStyle(WineTheme.cream)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(WineTheme.cardGradient)
        .clipShape(Capsule())
        .overlay {
            Capsule()
                .stroke(WineTheme.gold.opacity(0.3), lineWidth: 0.5)
        }
    }
}
