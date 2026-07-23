import SwiftUI

enum AppTab: String, CaseIterable, Identifiable, Codable {
    case search, library, signed, status, settings
    var id: String { rawValue }

    var title: String {
        switch self {
        case .search: return "Search"
        case .library: return "Library"
        case .signed: return "Signed"
        case .status: return "Status"
        case .settings: return "Settings"
        }
    }

    var icon: String {
        switch self {
        case .search: return "magnifyingglass"
        case .library: return "star"
        case .signed: return "checkmark.seal"
        case .status: return "heart.text.square"
        case .settings: return "gear"
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .search: SearchView()
        case .library: LibraryView()
        case .signed: SignedView()
        case .status: StatusView()
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
