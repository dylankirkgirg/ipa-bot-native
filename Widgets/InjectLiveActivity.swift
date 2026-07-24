import ActivityKit
import WidgetKit
import SwiftUI

struct InjectLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: InjectActivityAttributes.self) { context in
            HStack(spacing: 12) {
                Image(systemName: icon(for: context.state.status))
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.appName).font(.headline).foregroundStyle(.white)
                    Text(context.state.detail).font(.caption).foregroundStyle(.white.opacity(0.7))
                }
                Spacer()
            }
            .padding()
            .activityBackgroundTint(Color.black)
            .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: icon(for: context.state.status))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.status.capitalized).font(.caption)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("\(context.attributes.appName) — \(context.state.detail)").font(.caption2)
                }
            } compactLeading: {
                Image(systemName: icon(for: context.state.status))
            } compactTrailing: {
                Text(context.state.status.prefix(1).uppercased())
            } minimal: {
                Image(systemName: icon(for: context.state.status))
            }
        }
    }

    private func icon(for status: String) -> String {
        switch status {
        case "done": return "checkmark.circle.fill"
        case "failed": return "xmark.circle.fill"
        default: return "hourglass"
        }
    }
}

@main
struct IPABotWidgetsBundle: WidgetBundle {
    var body: some Widget {
        InjectLiveActivity()
        StatusWidget()
    }
}
