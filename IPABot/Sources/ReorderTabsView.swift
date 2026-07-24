import SwiftUI

struct ReorderTabsView: View {
    @EnvironmentObject var tabOrder: TabOrderStore

    var body: some View {
        List {
            Section {
                ForEach(tabOrder.order) { tab in
                    Label(tab.title, systemImage: tab.icon)
                }
                .onMove { indices, newOffset in
                    tabOrder.order.move(fromOffsets: indices, toOffset: newOffset)
                }
            } footer: {
                Text("Drag to reorder your tab bar.")
            }
        }
        .ledgerBackground()
        .scrollIndicators(.hidden)
        .navigationTitle("Reorder Tabs")
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.editMode, .constant(.active))
    }
}
