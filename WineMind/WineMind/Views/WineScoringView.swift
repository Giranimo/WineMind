import SwiftUI
import SwiftData

struct WineScoringView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var consentStore: PrivacyConsentStore

    let photoData: Data?

    @State private var name: String
    @State private var winery: String
    @State private var variety: String
    @State private var region: String
    @State private var vintage: Int
    @State private var color: WineColor
    @State private var body_: WineBody
    @State private var sweetness: WineSweetness
    @State private var score: Double = 7.0
    @State private var notes: String = ""

    init(wineInfo: WineInfo, photoData: Data?) {
        self.photoData = photoData
        _name = State(initialValue: wineInfo.name)
        _winery = State(initialValue: wineInfo.winery)
        _variety = State(initialValue: wineInfo.variety)
        _region = State(initialValue: wineInfo.region)
        _vintage = State(initialValue: wineInfo.vintage)
        _color = State(initialValue: wineInfo.color)
        _body_ = State(initialValue: wineInfo.body)
        _sweetness = State(initialValue: wineInfo.sweetness)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                WineTheme.backgroundGradient.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        // Photo preview
                        if let data = photoData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(WineTheme.gold.opacity(0.4), lineWidth: 1)
                                }
                                .padding(.horizontal)
                        }

                        // Score selector — front and center
                        scoreSection

                        // Wine details
                        wineDetailsSection

                        // Characteristics
                        characteristicsSection

                        // Tasting notes
                        notesSection

                        Spacer().frame(height: 20)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Rate This Wine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(WineTheme.mutedText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveWine() }
                        .font(.wineBody.weight(.bold))
                        .foregroundStyle(name.isEmpty ? WineTheme.dimText : WineTheme.gold)
                        .disabled(name.isEmpty)
                }
            }
        }
    }

    private var scoreSection: some View {
        VStack(spacing: 12) {
            Text(String(format: "%.1f", score))
                .font(.wineScore)
                .foregroundStyle(WineTheme.scoreColor(score))

            Text(WineTheme.scoreLabel(score))
                .font(.wineCallout)
                .italic()
                .foregroundStyle(WineTheme.gold)

            Slider(value: $score, in: 1...10, step: 0.5)
                .tint(WineTheme.scoreColor(score))
                .padding(.horizontal, 40)

            HStack {
                Text("1.0")
                Spacer()
                Text("10.0")
            }
            .font(.wineCaption)
            .foregroundStyle(WineTheme.dimText)
            .padding(.horizontal, 40)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(WineTheme.cardGradient)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    private var wineDetailsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Wine Details")

            VStack(spacing: 12) {
                styledTextField("Wine Name", text: $name)
                styledTextField("Winery", text: $winery)
                styledTextField("Grape Variety", text: $variety)
                styledTextField("Region", text: $region)

                HStack {
                    Text("Vintage")
                        .foregroundStyle(WineTheme.mutedText)
                    Spacer()
                    Picker("Vintage", selection: $vintage) {
                        ForEach((1990...Calendar.current.component(.year, from: Date())).reversed(), id: \.self) { year in
                            Text(String(year)).tag(year)
                        }
                    }
                    .tint(WineTheme.gold)
                }
                .padding(12)
                .background(WineTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(.horizontal)
    }

    private var characteristicsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Characteristics")

            VStack(spacing: 12) {
                stylePicker("Color", selection: $color, options: WineColor.allCases) { $0.rawValue }
                stylePicker("Body", selection: $body_, options: WineBody.allCases) { $0.rawValue }
                stylePicker("Sweetness", selection: $sweetness, options: WineSweetness.allCases) { $0.rawValue }
            }
        }
        .padding(.horizontal)
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader("Tasting Notes")

            TextEditor(text: $notes)
                .scrollContentBackground(.hidden)
                .background(WineTheme.surface)
                .foregroundStyle(WineTheme.cream)
                .font(.wineBody)
                .frame(minHeight: 100)
                .padding(8)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay {
                    if notes.isEmpty {
                        VStack {
                            HStack {
                                Text("Describe what you taste — fruit, oak, spice, finish...")
                                    .font(.wineBody)
                                    .italic()
                                    .foregroundStyle(WineTheme.dimText)
                                    .padding(.leading, 12)
                                    .padding(.top, 14)
                                Spacer()
                            }
                            Spacer()
                        }
                        .allowsHitTesting(false)
                    }
                }
        }
        .padding(.horizontal)
    }

    private func sectionHeader(_ text: String) -> some View {
        HStack {
            Text(text.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(2)
                .foregroundStyle(WineTheme.gold)
            Rectangle()
                .fill(WineTheme.gold.opacity(0.3))
                .frame(height: 0.5)
        }
    }

    private func styledTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField("", text: text, prompt: Text(placeholder).foregroundStyle(WineTheme.dimText))
            .font(.wineBody)
            .foregroundStyle(WineTheme.cream)
            .padding(12)
            .background(WineTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func stylePicker<T: Hashable>(_ label: String, selection: Binding<T>, options: [T], labelFor: @escaping (T) -> String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(WineTheme.mutedText)
            Spacer()
            Picker(label, selection: selection) {
                ForEach(options, id: \.self) { option in
                    Text(labelFor(option)).tag(option)
                }
            }
            .tint(WineTheme.gold)
        }
        .padding(12)
        .background(WineTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func saveWine() {
        let wine = Wine(
            name: name,
            winery: winery,
            variety: variety,
            region: region,
            vintage: vintage,
            score: score,
            notes: notes,
            photoData: photoData,
            color: color,
            body: body_,
            sweetness: sweetness
        )
        modelContext.insert(wine)

        // Sync to CloudKit only if the user has consented.
        // Public contribution is gated by a separate, granular consent flag.
        if consentStore.consent.allowsCloudSync {
            let contributesAnonymously = consentStore.consent.allowsAnonymousContribution
            Task {
                try? await CloudKitService.shared.saveWine(wine, contributeAnonymously: contributesAnonymously)
            }
        }

        dismiss()
    }
}
