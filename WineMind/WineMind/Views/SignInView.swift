import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @EnvironmentObject var auth: AuthService

    var body: some View {
        ZStack {
            WineTheme.backgroundGradient
                .ignoresSafeArea()

            // Decorative wine glass watermark
            Image(systemName: "wineglass")
                .font(.system(size: 360))
                .foregroundStyle(WineTheme.burgundy.opacity(0.08))
                .offset(x: 80, y: -40)
                .rotationEffect(.degrees(15))

            VStack(spacing: 32) {
                Spacer()

                // Logo & title
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(WineTheme.burgundyGradient)
                            .frame(width: 100, height: 100)
                            .shadow(color: WineTheme.burgundy.opacity(0.5), radius: 20)

                        Image(systemName: "wineglass.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(WineTheme.champagne)
                    }

                    Text("WineMind")
                        .font(.wineDisplay)
                        .foregroundStyle(WineTheme.cream)

                    GoldDivider()
                        .frame(width: 120)

                    Text("Your personal sommelier")
                        .font(.wineCallout)
                        .foregroundStyle(WineTheme.gold)
                        .italic()
                }

                Spacer()

                // Features
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(icon: "camera.viewfinder", text: "Snap a photo of any wine label")
                    FeatureRow(icon: "star.fill", text: "Rate and remember every bottle")
                    FeatureRow(icon: "sparkles", text: "Discover wines you'll love")
                    FeatureRow(icon: "icloud.fill", text: "Synced across all your devices")
                }
                .padding(.horizontal, 32)

                Spacer()

                // Sign in button
                VStack(spacing: 12) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        auth.handleAppleSignIn(result: result)
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 32)

                    if let error = auth.errorMessage {
                        Text(error)
                            .font(.wineCaption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }

                    Text("Your wine collection syncs privately via iCloud.\nAnonymized ratings power recommendations for everyone.")
                        .font(.wineCaption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(WineTheme.dimText)
                        .padding(.horizontal, 32)
                }

                Spacer().frame(height: 40)
            }
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(WineTheme.gold)
                .frame(width: 32)
            Text(text)
                .font(.wineBody)
                .foregroundStyle(WineTheme.cream)
            Spacer()
        }
    }
}
