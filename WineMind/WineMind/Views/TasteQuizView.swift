import SwiftUI

struct TasteQuizView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var profileStore: TasteProfileStore

    @State private var currentStep: Int = 0
    @State private var profile = TasteProfile.empty

    // Step inputs
    @State private var selectedColors: Set<WineColor> = []
    @State private var selectedBody: WineBody?
    @State private var selectedSweetness: WineSweetness?
    @State private var selectedFlavors: Set<FlavorProfile> = []
    @State private var selectedVarieties: Set<String> = []
    @State private var selectedRegions: Set<String> = []
    @State private var selectedExperience: WineExperience = .casual

    private var totalSteps: Int { 7 }

    // Suggested options for variety/region (popular picks)
    private let varietyOptions = [
        "Cabernet Sauvignon", "Pinot Noir", "Merlot", "Syrah",
        "Chardonnay", "Sauvignon Blanc", "Riesling", "Pinot Grigio",
        "Malbec", "Tempranillo", "Sangiovese", "Champagne"
    ]
    private let regionOptions = [
        "Bordeaux", "Burgundy", "Champagne", "Tuscany",
        "Napa Valley", "Sonoma", "Rioja", "Mendoza",
        "Barossa Valley", "Marlborough", "Mosel", "Douro"
    ]

    var body: some View {
        ZStack {
            WineTheme.backgroundGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                progressHeader

                TabView(selection: $currentStep) {
                    welcomeStep.tag(0)
                    colorStep.tag(1)
                    bodyStep.tag(2)
                    sweetnessStep.tag(3)
                    flavorStep.tag(4)
                    varietyStep.tag(5)
                    experienceStep.tag(6)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentStep)

                bottomBar
            }
        }
    }

    // MARK: - Header

    private var progressHeader: some View {
        VStack(spacing: 12) {
            HStack {
                if currentStep > 0 {
                    Button {
                        withAnimation { currentStep -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(WineTheme.mutedText)
                    }
                }
                Spacer()
                if currentStep > 0 {
                    Button("Skip") { complete() }
                        .font(.wineCaption)
                        .foregroundStyle(WineTheme.dimText)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            // Progress dots
            HStack(spacing: 6) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Capsule()
                        .fill(i <= currentStep ? WineTheme.gold : WineTheme.divider)
                        .frame(height: 3)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer().frame(height: 40)

                ZStack {
                    Circle()
                        .fill(WineTheme.burgundyGradient)
                        .frame(width: 110, height: 110)
                        .shadow(color: WineTheme.burgundy.opacity(0.5), radius: 20)
                    Image(systemName: "wineglass.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(WineTheme.champagne)
                }

                VStack(spacing: 8) {
                    Text("Calibrate Your Palate")
                        .font(.wineTitle)
                        .foregroundStyle(WineTheme.cream)
                        .multilineTextAlignment(.center)

                    GoldDivider().frame(width: 100)

                    Text("A quick 6-question quiz so we can\nrecommend wines you'll actually love")
                        .font(.wineCallout)
                        .italic()
                        .multilineTextAlignment(.center)
                        .foregroundStyle(WineTheme.mutedText)
                        .lineSpacing(3)
                }
                .padding(.horizontal, 30)

                VStack(spacing: 10) {
                    QuizBenefitRow(icon: "sparkles", text: "Predictions from your first scan")
                    QuizBenefitRow(icon: "person.crop.circle", text: "Personalized from day one")
                    QuizBenefitRow(icon: "clock", text: "Takes less than a minute")
                }
                .padding(.horizontal, 30)
                .padding(.top, 12)

                Spacer()
            }
        }
    }

    private var colorStep: some View {
        quizStep(
            title: "Which wines do you usually enjoy?",
            subtitle: "Tap all that apply",
            content: AnyView(
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(WineColor.allCases, id: \.self) { color in
                        QuizCard(
                            icon: color.systemImage,
                            title: color.rawValue,
                            isSelected: selectedColors.contains(color)
                        ) {
                            toggleSet(&selectedColors, color)
                        }
                    }
                }
            )
        )
    }

    private var bodyStep: some View {
        quizStep(
            title: "Light & easy, or bold & full?",
            subtitle: "Pick what you usually reach for",
            content: AnyView(
                VStack(spacing: 12) {
                    ForEach(WineBody.allCases, id: \.self) { body in
                        QuizCard(
                            icon: bodyIcon(body),
                            title: bodyTitle(body),
                            subtitle: bodyDescription(body),
                            isSelected: selectedBody == body,
                            wide: true
                        ) {
                            selectedBody = body
                        }
                    }
                }
            )
        )
    }

    private var sweetnessStep: some View {
        quizStep(
            title: "How dry do you like it?",
            subtitle: "Most table wines are dry",
            content: AnyView(
                VStack(spacing: 12) {
                    ForEach(WineSweetness.allCases, id: \.self) { s in
                        QuizCard(
                            icon: sweetnessIcon(s),
                            title: s.rawValue,
                            subtitle: sweetnessDescription(s),
                            isSelected: selectedSweetness == s,
                            wide: true
                        ) {
                            selectedSweetness = s
                        }
                    }
                }
            )
        )
    }

    private var flavorStep: some View {
        quizStep(
            title: "What flavors do you love?",
            subtitle: "Pick up to 3",
            content: AnyView(
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(FlavorProfile.allCases, id: \.self) { flavor in
                        QuizCard(
                            icon: flavor.icon,
                            title: flavor.rawValue,
                            isSelected: selectedFlavors.contains(flavor)
                        ) {
                            if selectedFlavors.contains(flavor) {
                                selectedFlavors.remove(flavor)
                            } else if selectedFlavors.count < 3 {
                                selectedFlavors.insert(flavor)
                            }
                        }
                    }
                }
            )
        )
    }

    private var varietyStep: some View {
        quizStep(
            title: "Any favorite grapes or regions?",
            subtitle: "Optional — tap any that you love",
            content: AnyView(
                VStack(alignment: .leading, spacing: 16) {
                    Text("GRAPES")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(WineTheme.gold)

                    FlowLayout(spacing: 8) {
                        ForEach(varietyOptions, id: \.self) { variety in
                            QuizChip(
                                label: variety,
                                isSelected: selectedVarieties.contains(variety)
                            ) {
                                toggleSet(&selectedVarieties, variety)
                            }
                        }
                    }

                    Text("REGIONS")
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(2)
                        .foregroundStyle(WineTheme.gold)
                        .padding(.top, 8)

                    FlowLayout(spacing: 8) {
                        ForEach(regionOptions, id: \.self) { region in
                            QuizChip(
                                label: region,
                                isSelected: selectedRegions.contains(region)
                            ) {
                                toggleSet(&selectedRegions, region)
                            }
                        }
                    }
                }
            )
        )
    }

    private var experienceStep: some View {
        quizStep(
            title: "How would you describe yourself?",
            subtitle: "We'll tune the language we use",
            content: AnyView(
                VStack(spacing: 12) {
                    ForEach(WineExperience.allCases, id: \.self) { exp in
                        QuizCard(
                            icon: exp.icon,
                            title: exp.rawValue,
                            isSelected: selectedExperience == exp,
                            wide: true
                        ) {
                            selectedExperience = exp
                        }
                    }
                }
            )
        )
    }

    // MARK: - Step container

    private func quizStep(title: String, subtitle: String, content: AnyView) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.wineTitle2)
                        .foregroundStyle(WineTheme.cream)
                    Text(subtitle)
                        .font(.wineCallout)
                        .italic()
                        .foregroundStyle(WineTheme.mutedText)
                }
                .padding(.top, 30)

                content

                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(WineTheme.divider)
                .frame(height: 0.5)

            HStack(spacing: 12) {
                Button {
                    if currentStep == totalSteps - 1 {
                        complete()
                    } else {
                        withAnimation { currentStep += 1 }
                    }
                } label: {
                    HStack {
                        Text(currentStep == 0 ? "Start" :
                             currentStep == totalSteps - 1 ? "Save Profile" : "Continue")
                            .font(.wineBody.weight(.semibold))
                        Image(systemName: "arrow.right")
                            .font(.caption.bold())
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(WineButtonStyle(prominent: true))
                .disabled(!canProceed)
                .opacity(canProceed ? 1 : 0.5)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .background(WineTheme.background.ignoresSafeArea(edges: .bottom))
    }

    private var canProceed: Bool {
        switch currentStep {
        case 0: return true
        case 1: return !selectedColors.isEmpty
        case 2: return selectedBody != nil
        case 3: return selectedSweetness != nil
        case 4: return true // flavors optional
        case 5: return true // varieties/regions optional
        case 6: return true
        default: return false
        }
    }

    private func complete() {
        let final = TasteProfile(
            preferredColors: selectedColors.isEmpty ? [.red, .white] : selectedColors,
            preferredBody: selectedBody ?? .medium,
            preferredSweetness: selectedSweetness ?? .dry,
            preferredFlavors: selectedFlavors,
            preferredVarieties: selectedVarieties,
            preferredRegions: selectedRegions,
            experience: selectedExperience
        )
        profileStore.save(final)
        dismiss()
    }

    // MARK: - Helpers

    private func toggleSet<T: Hashable>(_ set: inout Set<T>, _ value: T) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }

    private func bodyIcon(_ body: WineBody) -> String {
        switch body {
        case .light: return "leaf.fill"
        case .medium: return "scalemass.fill"
        case .full: return "shield.fill"
        }
    }

    private func bodyTitle(_ body: WineBody) -> String {
        switch body {
        case .light: return "Light & Crisp"
        case .medium: return "Medium-Bodied"
        case .full: return "Bold & Full"
        }
    }

    private func bodyDescription(_ body: WineBody) -> String {
        switch body {
        case .light: return "Pinot Noir, Riesling, Pinot Grigio"
        case .medium: return "Merlot, Chianti, Chardonnay"
        case .full: return "Cabernet, Syrah, Malbec"
        }
    }

    private func sweetnessIcon(_ s: WineSweetness) -> String {
        switch s {
        case .dry: return "drop"
        case .offDry: return "drop.halffull"
        case .sweet: return "drop.fill"
        }
    }

    private func sweetnessDescription(_ s: WineSweetness) -> String {
        switch s {
        case .dry: return "Almost no sweetness — most table wines"
        case .offDry: return "A hint of sweetness — many Rieslings"
        case .sweet: return "Noticeably sweet — dessert wines, Moscato"
        }
    }
}

// MARK: - Components

struct QuizBenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(WineTheme.gold)
                .frame(width: 24)
            Text(text)
                .font(.wineCallout)
                .foregroundStyle(WineTheme.cream)
            Spacer()
        }
    }
}

struct QuizCard: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    let isSelected: Bool
    var wide: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: wide ? 14 : 0) {
                if wide {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(isSelected ? WineTheme.gold : WineTheme.mutedText)
                        .frame(width: 44, height: 44)
                        .background(isSelected ? WineTheme.gold.opacity(0.1) : WineTheme.surface)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.wineBody.weight(.semibold))
                            .foregroundStyle(WineTheme.cream)
                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(.wineCaption)
                                .italic()
                                .foregroundStyle(WineTheme.mutedText)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(WineTheme.gold)
                    }
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: icon)
                            .font(.system(size: 28))
                            .foregroundStyle(isSelected ? WineTheme.gold : WineTheme.mutedText)
                        Text(title)
                            .font(.wineCallout.weight(.semibold))
                            .foregroundStyle(WineTheme.cream)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                }
            }
            .padding(wide ? 12 : 0)
            .background(isSelected ? WineTheme.surfaceElevated : WineTheme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? WineTheme.gold : WineTheme.divider, lineWidth: isSelected ? 1.5 : 0.5)
            }
        }
        .buttonStyle(.plain)
    }
}

struct QuizChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.wineCaption.weight(.semibold))
                .foregroundStyle(isSelected ? WineTheme.cream : WineTheme.mutedText)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isSelected ? WineTheme.burgundy.opacity(0.6) : WineTheme.surface)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(isSelected ? WineTheme.gold.opacity(0.8) : WineTheme.divider, lineWidth: 0.5)
                }
        }
        .buttonStyle(.plain)
    }
}

// Simple flow layout for chips
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var totalHeight: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth {
                totalHeight += rowHeight + spacing
                rowWidth = size.width + spacing
                rowHeight = size.height
            } else {
                rowWidth += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
