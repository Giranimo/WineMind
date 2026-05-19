import SwiftUI
import SwiftData

struct WineListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Wine.dateAdded, order: .reverse) private var wines: [Wine]
    @State private var showingCamera = false
    @State private var searchText = ""
    @State private var filterColor: WineColor?

    var filteredWines: [Wine] {
        wines.filter { wine in
            let matchesSearch = searchText.isEmpty ||
                wine.name.localizedCaseInsensitiveContains(searchText) ||
                wine.winery.localizedCaseInsensitiveContains(searchText) ||
                wine.variety.localizedCaseInsensitiveContains(searchText)
            let matchesFilter = filterColor == nil || wine.color == filterColor
            return matchesSearch && matchesFilter
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                WineTheme.backgroundGradient.ignoresSafeArea()

                if wines.isEmpty {
                    emptyState
                } else {
                    wineList
                }
            }
            .navigationTitle("Cellar")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCamera = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(WineTheme.gold)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("All Wines") { filterColor = nil }
                        Divider()
                        ForEach(WineColor.allCases, id: \.self) { color in
                            Button {
                                filterColor = color
                            } label: {
                                Label(color.rawValue, systemImage: color.systemImage)
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundStyle(WineTheme.gold)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search your cellar...")
            .fullScreenCover(isPresented: $showingCamera) {
                CameraCaptureView()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(WineTheme.burgundy.opacity(0.15))
                    .frame(width: 140, height: 140)
                Image(systemName: "wineglass")
                    .font(.system(size: 72))
                    .foregroundStyle(WineTheme.gold)
            }

            VStack(spacing: 8) {
                Text("Your Cellar Awaits")
                    .font(.wineTitle)
                    .foregroundStyle(WineTheme.cream)

                GoldDivider()
                    .frame(width: 100)

                Text("Photograph a bottle to begin\nyour wine journey")
                    .font(.wineCallout)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(WineTheme.mutedText)
            }

            Button {
                showingCamera = true
            } label: {
                Label("Add First Wine", systemImage: "camera.fill")
            }
            .buttonStyle(WineButtonStyle(prominent: true))

            Spacer()
        }
        .padding()
    }

    private var wineList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if filterColor != nil {
                    HStack {
                        Text("Filtering by \(filterColor!.rawValue)")
                            .font(.wineCaption)
                            .foregroundStyle(WineTheme.gold)
                        Spacer()
                        Button("Clear") { filterColor = nil }
                            .font(.wineCaption.bold())
                            .foregroundStyle(WineTheme.burgundyLight)
                    }
                    .padding(.horizontal)
                }

                ForEach(filteredWines) { wine in
                    NavigationLink(destination: WineDetailView(wine: wine)) {
                        WineRowView(wine: wine)
                    }
                    .buttonStyle(.plain)
                    .swipeActions {
                        Button(role: .destructive) {
                            modelContext.delete(wine)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }
}

struct WineRowView: View {
    let wine: Wine

    var body: some View {
        HStack(spacing: 14) {
            if let photo = wine.photo {
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 72, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(WineTheme.gold.opacity(0.3), lineWidth: 0.5)
                    }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(WineTheme.surfaceElevated)
                    .frame(width: 72, height: 96)
                    .overlay {
                        Image(systemName: "wineglass")
                            .font(.title)
                            .foregroundStyle(WineTheme.burgundy.opacity(0.5))
                    }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(wine.name.isEmpty ? "Unknown Wine" : wine.name)
                    .font(.wineTitle3)
                    .foregroundStyle(WineTheme.cream)
                    .lineLimit(1)

                if !wine.winery.isEmpty {
                    Text(wine.winery)
                        .font(.wineSubheadline)
                        .foregroundStyle(WineTheme.gold)
                        .italic()
                        .lineLimit(1)
                }

                HStack(spacing: 8) {
                    if !wine.variety.isEmpty {
                        Text(wine.variety)
                            .font(.wineCaption)
                            .foregroundStyle(WineTheme.mutedText)
                            .lineLimit(1)
                    }
                    Text("·")
                        .foregroundStyle(WineTheme.dimText)
                    Text("\(wine.vintage)")
                        .font(.wineCaption)
                        .foregroundStyle(WineTheme.mutedText)
                }
            }

            Spacer()

            if wine.score > 0 {
                ScoreBadge(score: wine.score)
            }
        }
        .padding(14)
        .background(WineTheme.cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(WineTheme.divider, lineWidth: 0.5)
        }
    }
}

struct ScoreBadge: View {
    let score: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(WineTheme.scoreColor(score), lineWidth: 1.5)
                .frame(width: 48, height: 48)
            Text(String(format: "%.1f", score))
                .font(.wineScoreSmall)
                .foregroundStyle(WineTheme.scoreColor(score))
        }
    }
}
