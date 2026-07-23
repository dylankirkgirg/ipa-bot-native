import SwiftUI

struct ContentView: View {
    @EnvironmentObject var api: APIClient
    @State private var showSettings = false

    var body: some View {
        Group {
            if api.isConfigured {
                TabView {
                    SearchView()
                        .tabItem { Label("Search", systemImage: "magnifyingglass") }
                    LibraryView()
                        .tabItem { Label("Library", systemImage: "star") }
                    SignedView()
                        .tabItem { Label("Signed", systemImage: "checkmark.seal") }
                    StatusView()
                        .tabItem { Label("Status", systemImage: "heart.text.square") }
                    SettingsView()
                        .tabItem { Label("Settings", systemImage: "gear") }
                }
            } else {
                SettingsView(forceOnboarding: true)
            }
        }
    }
}
