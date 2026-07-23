import SwiftUI

struct HitRow: View {
    let hit: Hit
    var onStar: (() -> Void)? = nil
    var onDownload: (() -> Void)? = nil
    var onSign: (() -> Void)? = nil
    var onInject: (() -> Void)? = nil

    var body: some View {
        WebCard {
            HStack(alignment: .top, spacing: 12) {
                AsyncImage(url: hit.icon_url.flatMap(URL.init)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.white.opacity(0.06))
                            .overlay(Text(hit.emoji.isEmpty ? "📦" : hit.emoji).font(.title3))
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 2) {
                    Text(hit.app_name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(WebTheme.textPrimary)
                        .lineLimit(1)
                    Text(hit.bundle_id)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(WebTheme.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                if let onStar {
                    Button(action: onStar) {
                        Image(systemName: (hit.starred ?? false) ? "star.fill" : "star")
                            .foregroundStyle((hit.starred ?? false) ? WebTheme.warning : WebTheme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 6) {
                WebPill(text: "v\(hit.version)")
                WebPill(text: hit.source)
                if hit.size_mb > 0 { WebPill(text: "\(Int(hit.size_mb)) MB") }
                if hit.is_modded == true {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                }
            }

            if onDownload != nil || onSign != nil || onInject != nil {
                HStack(spacing: 8) {
                    if let onDownload {
                        Button("Download .ipa", action: onDownload)
                            .buttonStyle(WebPrimaryButtonStyle())
                    }
                    if let onSign {
                        Button(action: onSign) {
                            Image(systemName: "signature")
                        }
                        .buttonStyle(WebPrimaryButtonStyle(color: WebTheme.card))
                        .frame(width: 44)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(WebTheme.cardBorder, lineWidth: 1))
                    }
                    if let onInject {
                        Button(action: onInject) {
                            Image(systemName: "wrench.and.screwdriver.fill")
                        }
                        .buttonStyle(WebPrimaryButtonStyle(color: WebTheme.card))
                        .frame(width: 44)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(WebTheme.cardBorder, lineWidth: 1))
                    }
                }
            }
        }
    }
}
