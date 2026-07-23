import SwiftUI

struct HitRow: View {
    let hit: Hit
    var onStar: (() -> Void)? = nil
    var onDownload: (() -> Void)? = nil
    var onInject: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            AsyncImage(url: hit.icon_url.flatMap(URL.init)) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    RoundedRectangle(cornerRadius: 14)
                        .fill(LinearGradient(colors: [.accentColor.opacity(0.4), .accentColor.opacity(0.15)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(Text(hit.emoji.isEmpty ? "📦" : hit.emoji).font(.title2))
                }
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color(.separator).opacity(0.4), lineWidth: 0.5))

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Text(hit.app_name)
                        .font(.system(.subheadline, weight: .semibold))
                        .lineLimit(1)
                    if hit.is_modded == true {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                    }
                }
                HStack(spacing: 6) {
                    pill("v\(hit.version)")
                    pill(hit.source)
                    if hit.size_mb > 0 { pill("\(Int(hit.size_mb)) MB") }
                }
            }

            Spacer(minLength: 4)

            HStack(spacing: 18) {
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
            .font(.system(size: 17))
        }
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private func pill(_ text: String) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.secondary.opacity(0.12), in: Capsule())
    }
}
