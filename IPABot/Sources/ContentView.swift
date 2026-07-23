import SwiftUI

struct ContentView: View {
    @EnvironmentObject var api: APIClient
    @StateObject private var tabOrder = TabOrderStore()

    var body: some View {
        Group {
            if api.isConfigured {
                TabView {
                    ForEach(tabOrder.order) { tab in
                        tab.destination
                            .tabItem { Label(tab.title, systemImage: tab.icon) }
                    }
                }
                .environmentObject(tabOrder)
            } else {
                SettingsView(forceOnboarding: true)
            }
        }
    }
}
