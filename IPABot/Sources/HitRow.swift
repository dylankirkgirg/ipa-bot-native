import SwiftUI

struct HitRow: View {
    let hit: Hit
    var onStar: (() -> Void)? = nil
    var onDownload: (() -> Void)? = nil
    var onSign: (() -> Void)? = nil
    var onInject: (() -> Void)? = nil
    /// False when there's no download source (no direct URL, no vault copy) —
    /// Sign/Inject/Download show disabled instead of vanishing, so it's clear
    /// the app *can't* be delivered rather than looking like the row is broken.
    var canDeliver: Bool = true

    private var isStarred: Bool { hit.starred ?? false }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                AsyncImage(url: hit.icon_url.flatMap(URL.init)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Rectangle().fill(Ledger.surface)
                            .overlay(
                                Text(hit.emoji.isEmpty ? String(hit.app_name.prefix(1)).uppercased() : hit.emoji)
                                    .font(Ledger.heading(16))
                                    .foregroundColor(Ledger.textTertiary)
                            )
                    }
                }
                .frame(width: 48, height: 48)
                .clipped()
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .top, spacing: 6) {
                        Text(hit.app_name)
                            .font(Ledger.heading(15, weight: .semibold))
                            .foregroundColor(Ledger.text)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        if let onStar {
                            Button(action: onStar) {
                                Glyph(.star, size: 16, color: isStarred ? Ledger.accent : Ledger.textTertiary)
                            }
                            .buttonStyle(.plain)
                            .frame(width: 44, height: 44).contentShape(Rectangle())
                            .accessibilityLabel(isStarred ? "Unstar" : "Star")
                        }
                    }
                    Text(hit.bundle_id)
                        .font(Ledger.mono(11))
                        .foregroundColor(Ledger.textSecondary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(tagLine)
                            .font(Ledger.mono(11))
                            .foregroundColor(Ledger.textTertiary)
                        if SourceHealth.isFlaky(source: hit.source) {
                            Circle().fill(Ledger.accent).frame(width: 5, height: 5)
                                .accessibilityLabel("This source has failed recently")
                        }
                    }
                }
            }

            if onDownload != nil || onSign != nil || onInject != nil {
                HStack(spacing: 6) {
                    if let onDownload {
                        Button("Download .ipa", action: onDownload)
                            .buttonStyle(LedgerPrimaryButtonStyle())
                            .disabled(!canDeliver)
                            .opacity(canDeliver ? 1 : 0.4)
                    }
                    if let onSign {
                        Button(action: onSign) { Glyph(.sign, size: 15, color: canDeliver ? .white : Ledger.textTertiary) }
                            .buttonStyle(LedgerIconButtonStyle(background: canDeliver ? Ledger.accent : .clear, border: canDeliver ? .clear : Ledger.divider))
                            .disabled(!canDeliver)
                            .accessibilityLabel("Sign")
                            .accessibilityHint(canDeliver ? "Signs and queues this app for install" : "Unavailable — no download source for this app")
                    }
                    if let onInject {
                        Button(action: onInject) { Glyph(.inject, size: 15, color: canDeliver ? Ledger.text : Ledger.textTertiary) }
                            .buttonStyle(LedgerIconButtonStyle())
                            .disabled(!canDeliver)
                            .accessibilityLabel("Inject tweaks")
                            .accessibilityHint(canDeliver ? "Choose tweaks to inject before signing" : "Unavailable — no download source for this app")
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .overlay(alignment: .leading) {
            if isStarred { Rectangle().fill(Ledger.accent).frame(width: 2) }
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Ledger.dividerSoft).frame(height: 1)
        }
    }

    private var tagLine: String {
        var parts = ["v\(hit.version)", hit.source]
        if hit.size_mb > 0 { parts.append("\(Int(hit.size_mb)) MB") }
        if hit.is_modded == true { parts.append("mod") }
        return parts.joined(separator: " · ")
    }
}
