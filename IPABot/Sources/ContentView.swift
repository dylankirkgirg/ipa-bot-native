import SwiftUI

struct ContentView: View {
    @EnvironmentObject var api: APIClient
    @StateObject private var tabOrder = TabOrderStore()
    @StateObject private var router = DeepLinkRouter()

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
        .onOpenURL { router.handle($0) }
        .sheet(item: Binding(
            get: { router.pendingSignURL.map { IdentifiableURLString(value: $0) } },
            set: { router.pendingSignURL = $0?.value }
        )) { wrapped in
            SignInstallView(prefillURL: wrapped.value)
        }
    }
}

private struct IdentifiableURLString: Identifiable {
    let value: String
    var id: String { value }
}
