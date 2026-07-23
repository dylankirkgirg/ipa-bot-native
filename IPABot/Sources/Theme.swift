import SwiftUI

// Exact color values sampled from the live web app (ipa-bot.dihblud1.workers.dev)
// via getComputedStyle, so the native app matches pixel-for-pixel instead of
// approximating with system colors.
enum WebTheme {
    static let background = Color(red: 12/255, green: 13/255, blue: 16/255)
    static let card = Color(red: 22/255, green: 23/255, blue: 28/255)
    static let cardBorder = Color.white.opacity(0.09)
    static let cardBorderStrong = Color.white.opacity(0.16)
    static let textPrimary = Color(red: 238/255, green: 241/255, blue: 247/255)
    static let textSecondary = Color.white.opacity(0.55)
    static let accent = Color(red: 77/255, green: 122/255, blue: 173/255)
    static let success = Color(red: 52/255, green: 211/255, blue: 153/255)
    static let successBg = success.opacity(0.15)
    static let successBorder = success.opacity(0.22)
    static let warning = Color(red: 250/255, green: 199/255, blue: 117/255)
    static let danger = Color(red: 224/255, green: 90/255, blue: 90/255)
}

struct WebCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(14)
        .background(WebTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(WebTheme.cardBorder, lineWidth: 1))
    }
}

struct WebPrimaryButtonStyle: ButtonStyle {
    var color: Color = WebTheme.accent
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct WebPill: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(WebTheme.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.06))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(WebTheme.cardBorder, lineWidth: 1))
    }
}

extension View {
    /// Applies the web app's dark background to a List/ScrollView, replacing
    /// the default system grouped background.
    func webBackground() -> some View {
        self.scrollContentBackground(.hidden).background(WebTheme.background)
    }
}
