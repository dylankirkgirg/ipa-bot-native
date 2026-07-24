import SwiftUI

struct ContentView: View {
    @EnvironmentObject var api: APIClient
    @StateObject private var tabOrder = TabOrderStore()
    @StateObject private var router = DeepLinkRouter()
    @State private var selectedTab: AppTab?
    @State private var showReportBug = false

    var body: some View {
        Group {
            if api.isConfigured {
                TabView(selection: $selectedTab) {
                    ForEach(tabOrder.order) { tab in
                        tab.destination
                            .tabItem { Label(tab.title, systemImage: tab.icon) }
                            .tag(Optional(tab))
                    }
                }
                .environmentObject(tabOrder)
            } else {
                SettingsView(forceOnboarding: true)
            }
        }
        .onOpenURL { router.handle($0) }
        .onChange(of: router.pendingTab) { tab in
            if let tab { selectedTab = tab; router.pendingTab = nil }
        }
        .sheet(item: Binding(
            get: { router.pendingSignURL.map { IdentifiableURLString(value: $0) } },
            set: { router.pendingSignURL = $0?.value }
        )) { wrapped in
            SignInstallView(prefillURL: wrapped.value)
        }
        .onShake { if api.isConfigured { showReportBug = true } }
        .sheet(isPresented: $showReportBug) { ReportBugView() }
    }
}

private struct IdentifiableURLString: Identifiable {
    let value: String
    var id: String { value }
}
