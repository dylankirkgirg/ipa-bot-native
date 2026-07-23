import SwiftUI

struct HitRow: View {
    let hit: Hit
    var onStar: (() -> Void)? = nil
    var onDownload: (() -> Void)? = nil
    var onSign: (() -> Void)? = nil
    var onInject: (() -> Void)? = nil

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
                        }
                    }
                    Text(hit.bundle_id)
                        .font(Ledger.mono(11))
                        .foregroundColor(Ledger.textSecondary)
                        .lineLimit(1)
                    Text(tagLine)
                        .font(Ledger.mono(11))
                        .foregroundColor(Ledger.textTertiary)
                }
            }

            if onDownload != nil || onSign != nil || onInject != nil {
                HStack(spacing: 6) {
                    if let onDownload {
                        Button("Download .ipa", action: onDownload)
                            .buttonStyle(LedgerPrimaryButtonStyle())
                    }
                    if let onSign {
                        Button(action: onSign) { Glyph(.sign, size: 15) }
                            .buttonStyle(LedgerIconButtonStyle(size: 40))
                    }
                    if let onInject {
                        Button(action: onInject) { Glyph(.inject, size: 15) }
                            .buttonStyle(LedgerIconButtonStyle(size: 40))
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
