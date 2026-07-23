import SwiftUI

enum AppTab: String, CaseIterable, Identifiable, Codable {
    case search, library, diagnostics, settings
    var id: String { rawValue }

    var title: String {
        switch self {
        case .search: return "Search"
        case .library: return "Library"
        case .diagnostics: return "Diagnostics"
        case .settings: return "Settings"
        }
    }

    // Tab bar icons stay SF Symbols on purpose — UITabBarItem rendering,
    // selection state and accessibility are all tuned around them, and
    // reproducing that faithfully with custom glyphs isn't worth the risk.
    // Every icon INSIDE the app (rows, buttons, headers) uses Glyph instead.
    var icon: String {
        switch self {
        case .search: return "magnifyingglass"
        case .library: return "tray.full"
        case .diagnostics: return "waveform.path.ecg"
        case .settings: return "gearshape"
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .search: SearchView()
        case .library: LibraryView()
        case .diagnostics: DiagnosticsView()
        case .settings: SettingsView()
        }
    }
}

/// Persists the user's chosen tab order across launches. Stored as a
/// comma-joined raw-value string since UserDefaults has no native array-of-
/// enum support; falls back to the default order for anything unparseable
/// or missing (e.g. a tab added in a later app version).
final class TabOrderStore: ObservableObject {
    @Published var order: [AppTab] {
        didSet { persist() }
    }

    private static let key = "ipabot.tabOrder"

    init() {
        if let raw = UserDefaults.standard.string(forKey: Self.key) {
            let saved = raw.split(separator: ",").compactMap { AppTab(rawValue: String($0)) }
            let missing = AppTab.allCases.filter { !saved.contains($0) }
            order = saved.isEmpty ? AppTab.allCases : saved + missing
        } else {
            order = AppTab.allCases
        }
    }

    private func persist() {
        UserDefaults.standard.set(order.map(\.rawValue).joined(separator: ","), forKey: Self.key)
    }
}
