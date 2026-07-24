import SwiftUI

struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(WhatsNew.currentEntries ?? [], id: \.self) { item in
                    HStack(alignment: .top, spacing: 10) {
                        Glyph(.check, size: 14, color: Ledger.accent).padding(.top, 2)
                        Text(item).font(Ledger.body(14)).foregroundColor(Ledger.text)
                    }
                    .listRowSeparator(.hidden).listRowBackground(Color.clear)
                }
            }
            .listStyle(.plain)
            .ledgerBackground()
            .navigationTitle("What's New in \(WhatsNew.currentVersion)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
