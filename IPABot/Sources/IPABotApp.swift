import SwiftUI

@main
struct IPABotApp: App {
    @StateObject private var api = APIClient.shared

    init() {
        Ledger.configureAppearance()
        BadgeUpdater.requestAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(api)
                .tint(Ledger.accent)
                .preferredColorScheme(api.theme.colorScheme)
        }
    }
}
