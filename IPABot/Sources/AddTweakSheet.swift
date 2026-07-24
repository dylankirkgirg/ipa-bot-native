import SwiftUI

struct AddTweakSheet: View {
    @EnvironmentObject var api: APIClient
    @Environment(\.dismiss) private var dismiss
    var onSaved: () -> Void

    @State private var id = ""
    @State private var bundle = ""
    @State private var name = ""
    @State private var repo = ""
    @State private var emoji = "🧪"
    @State private var isBusy = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("id (e.g. ytlite)", text: $id)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Bundle ID", text: $bundle)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Name", text: $name)
                    TextField("Repo URL", text: $repo)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Emoji", text: $emoji)
                } header: {
                    Text("Add Custom Tweak")
                } footer: {
                    Text("Saved to your catalog permanently — shows up for this bundle everywhere.")
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(Ledger.accent)
                }
            }
            .ledgerBackground()
            .scrollIndicators(.hidden)
            .navigationTitle("Add Tweak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(isBusy || id.isEmpty || bundle.isEmpty || name.isEmpty || repo.isEmpty)
                }
            }
        }
    }

    private func save() async {
        isBusy = true; errorMessage = nil
        do {
            let result = try await api.addTweak(id: id, bundle: bundle, name: name, repo: repo, emoji: emoji.isEmpty ? "🧪" : emoji)
            if result.ok {
                onSaved()
                dismiss()
            } else {
                errorMessage = result.error ?? "Couldn't save."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isBusy = false
    }
}
