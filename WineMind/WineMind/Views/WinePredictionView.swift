import SwiftUI
import SwiftData

struct WinePredictionView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var allWines: [Wine]
    @EnvironmentObject var profileStore: TasteProfileStore

    let wineInfo: WineInfo
    let photoData: Data?
    let onFinished: () -> Void

    @State private var prediction: WinePrediction?
    @State private var showingScoring = false
    @State private var animateIn = false

    private let predictor = WinePredictor()

    var body: some View {
        NavigationStack {
            ZStack {
                WineTheme.backgroundGradient.ignoresSafeArea()

                if let prediction = prediction {
                    predictionContent(prediction)
                } else {
                    ProgressView()
                        .tint(WineTheme.gold)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(WineTheme.mutedText)
                }
            }
            .fullScreenCover(isPresented: $showingScoring) {
                WineScoringView(wineInfo: wineInfo, photoData: photoData, onFinished: onFinished)
            }
            .task {
                prediction = predictor.predict(
                    wineInfo: wineInfo,
                    userWines: allWines,
                    tasteProfile: profileStore.profile
                )
                withAnimation(.spring(duration: 0.6).delay(0.1)) {
                    animateIn = true
                }
            }
        }
    }

    @ViewBuilder
    private func predictionContent(_ prediction: WinePrediction) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Wine photo preview
                if let data = photoData, let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(WineTheme.gold.opacity(0.4), lineWidth: 1)
                        }
                        .padding(.horizontal, 60)
                        .padding(.top, 20)
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : -10)
                }

                // Wine name
                VStack(spacing: 4) {
                    Text(wineInfo.name.isEmpty ? "Unknown Wine" : wineInfo.name)
                        .font(.wineTitle3)
                        .foregroundStyle(WineTheme.cream)
                        .multilineTextAlignment(.center)

                    if !wineInfo.variety.isEmpty {
                        Text("\(wineInfo.variety) · \(wineInfo.vintage)")
                            .font(.wineCaption)
                            .italic()
                            .foregroundStyle(WineTheme.gold)
                    }
                }
                .opacity(animateIn ? 1 : 0)

                GoldDivider()
                    .padding(.horizontal, 80)

                // VERDICT — the centerpiece
                VStack(spacing: 16) {
                    // Icon with halo
                    ZStack {
                        Circle()
                            .fill(verdictColor(prediction.verdict).opacity(0.15))
                            .frame(width: 120, height: 120)
                            .blur(radius: 12)

                        Circle()
                            .stroke(verdictColor(prediction.verdict).opacity(0.4), lineWidth: 1)
                            .frame(width: 100, height: 100)

                        Image(systemName: prediction.verdict.icon)
                            .font(.system(size: 44))
                            .foregroundStyle(verdictColor(prediction.verdict))
                            .symbolEffect(.bounce, value: animateIn)
                    }
                    .scaleEffect(animateIn ? 1 : 0.5)
                    .opacity(animateIn ? 1 : 0)

                    Text(prediction.verdict.headline)
                        .font(.system(size: 32, weight: .bold, design: .serif))
                        .foregroundStyle(verdictColor(prediction.verdict))
                        .multilineTextAlignment(.center)
                        .opacity(animateIn ? 1 : 0)
                        .offset(y: animateIn ? 0 : 10)

                    Text(prediction.verdict.subline)
                        .font(.wineCallout)
                        .italic()
                        .foregroundStyle(WineTheme.mutedText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .opacity(animateIn ? 1 : 0)
                }
                .padding(.vertical, 8)

                // Confidence meter
                if prediction.confidence > 0 {
                    confidenceMeter(prediction.confidence)
                        .opacity(animateIn ? 1 : 0)
                }

                // Reasons
                if !prediction.reasons.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("BASED ON")
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(2)
                            .foregroundStyle(WineTheme.gold)

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(prediction.reasons, id: \.self) { reason in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "checkmark.diamond.fill")
                                        .font(.caption)
                                        .foregroundStyle(WineTheme.gold)
                                        .padding(.top, 2)
                                    Text(reason)
                                        .font(.wineCallout)
                                        .foregroundStyle(WineTheme.cream)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(WineTheme.cardGradient)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .padding(.horizontal)
                    .opacity(animateIn ? 1 : 0)
                    .offset(y: animateIn ? 0 : 20)
                }

                // Actions
                VStack(spacing: 10) {
                    Button {
                        showingScoring = true
                    } label: {
                        Label("Rate This Wine", systemImage: "star.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(WineButtonStyle(prominent: true))

                    Button("Maybe Later") {
                        dismiss()
                    }
                    .font(.wineCaption)
                    .foregroundStyle(WineTheme.dimText)
                    .padding(.top, 4)
                }
                .padding(.horizontal)
                .padding(.top, 4)
                .opacity(animateIn ? 1 : 0)

                Spacer().frame(height: 30)
            }
        }
    }

    private func confidenceMeter(_ confidence: Double) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text("CONFIDENCE")
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(WineTheme.dimText)
                Spacer()
                Text(confidenceLabel(confidence))
                    .font(.wineCaption.bold())
                    .foregroundStyle(WineTheme.gold)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(WineTheme.divider)
                    RoundedRectangle(cornerRadius: 2)
                        .fill(WineTheme.goldGradient)
                        .frame(width: geo.size.width * confidence)
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 30)
    }

    private func confidenceLabel(_ confidence: Double) -> String {
        switch confidence {
        case 0.75...1.0: return "High"
        case 0.45..<0.75: return "Moderate"
        case 0.20..<0.45: return "Low"
        default: return "Very Low"
        }
    }

    private func verdictColor(_ verdict: Verdict) -> Color {
        switch verdict.color {
        case .gold: return WineTheme.gold
        case .green: return WineTheme.scoreExcellent
        case .amber: return WineTheme.scoreGood
        case .burgundy: return WineTheme.burgundyLight
        case .muted: return WineTheme.mutedText
        }
    }
}
