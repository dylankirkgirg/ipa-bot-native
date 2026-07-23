import SwiftUI

struct HitRow: View {
    let hit: Hit
    var onStar: (() -> Void)? = nil
    var onDownload: (() -> Void)? = nil
    var onInject: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: hit.icon_url.flatMap(URL.init)) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                RoundedRectangle(cornerRadius: 10).fill(.secondary.opacity(0.2))
                    .overlay(Text(hit.emoji))
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(hit.app_name).font(.headline)
                    if hit.is_modded == true {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                Text("v\(hit.version) · \(hit.source)" + (hit.size_mb > 0 ? " · \(Int(hit.size_mb)) MB" : ""))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

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
                }
                .buttonStyle(.plain)
            }
            if let onInject {
                Button(action: onInject) {
                    Image(systemName: "wrench.and.screwdriver")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
}
