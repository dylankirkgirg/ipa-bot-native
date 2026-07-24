import SwiftUI

struct AddPresetSheet: View {
    @EnvironmentObject var api: APIClient
    @Environment(\.dismiss) private var dismiss
    var onSaved: () -> Void

    @State private var name = ""
    @State private var tweaks: [Tweak] = []
    @State private var selected: Set<String> = []
    @State private var isLoadingTweaks = false
    @State private var isBusy = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Preset name", text: $name)
                        .autocorrectionDisabled()
                } header: {
                    Text("Add Preset")
                }
                Section("Tweaks (\(selected.count))") {
                    if isLoadingTweaks {
                        ProgressView()
                    }
                    ForEach(tweaks) { tweak in
                        Button {
                            if selected.contains(tweak.id) { selected.remove(tweak.id) }
                            else { selected.insert(tweak.id) }
                        } label: {
                            HStack {
                                Text(tweak.emoji)
                                Text(tweak.name).foregroundStyle(.primary)
                                Spacer()
                                if selected.contains(tweak.id) {
                                    Glyph(.check, size: 13, color: Ledger.accent)
                                }
                            }
                        }
                    }
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(Ledger.accent)
                }
            }
            .ledgerBackground()
            .scrollIndicators(.hidden)
            .navigationTitle("Add Preset")
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadTweaks() }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(isBusy || name.trimmingCharacters(in: .whitespaces).isEmpty || selected.isEmpty)
                }
            }
        }
    }

    private func loadTweaks() async {
        isLoadingTweaks = true
        do {
            tweaks = try await api.tweaks().tweaks
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingTweaks = false
    }

    private func save() async {
        isBusy = true; errorMessage = nil
        do {
            let result = try await api.savePreset(name: name.trimmingCharacters(in: .whitespaces), tweakIds: Array(selected))
            if result.ok {
                onSaved()
                dismiss()
            } else {
                errorMessage = result.error ?? "Couldn't save preset."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isBusy = false
    }
}
