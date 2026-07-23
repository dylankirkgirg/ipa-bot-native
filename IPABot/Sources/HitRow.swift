import SwiftUI

struct HitRow: View {
    let hit: Hit
    var onStar: (() -> Void)? = nil
    var onDownload: (() -> Void)? = nil
    var onInject: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: hit.icon_url.flatMap(URL.init)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    RoundedRectangle(cornerRadius: 9)
                        .fill(Color(.tertiarySystemFill))
                        .overlay(Text(hit.emoji.isEmpty ? "📦" : hit.emoji).font(.subheadline))
                }
            }
            .frame(width: 36, height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 1) {
                Text(hit.app_name)
                    .font(.system(.body))
                    .lineLimit(1)
                Text(metaLine)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if hit.is_modded == true {
                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            HStack(spacing: 16) {
                if let onStar {
                    Button(action: onStar) {
                        Image(systemName: (hit.starred ?? false) ? "star.fill" : "star")
                            .foregroundStyle((hit.starred ?? false) ? .yellow : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                if let onDownload {
                    Button(action: onDownload) {
                        Image(systemName: "arrow.down.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                if let onInject {
                    Button(action: onInject) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            .font(.system(size: 16))
        }
        .padding(.vertical, 6)
    }

    private var metaLine: String {
        var parts = ["v\(hit.version)", hit.source]
        if hit.size_mb > 0 { parts.append("\(Int(hit.size_mb)) MB") }
        return parts.joined(separator: " · ")
    }
}
