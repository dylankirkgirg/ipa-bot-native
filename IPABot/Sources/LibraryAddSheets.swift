import SwiftUI

private struct FieldSheet: View {
    @EnvironmentObject var api: APIClient
    @Environment(\.dismiss) private var dismiss

    let title: String
    let fields: [(label: String, keyboard: UIKeyboardType, secure: Bool)]
    let submit: ([String]) async throws -> ActionResult
    var onSaved: () -> Void = {}

    @State private var values: [String]
    @State private var isBusy = false
    @State private var errorMessage: String?

    init(title: String, fields: [(label: String, keyboard: UIKeyboardType, secure: Bool)],
         submit: @escaping ([String]) async throws -> ActionResult, onSaved: @escaping () -> Void = {}) {
        self.title = title
        self.fields = fields
        self.submit = submit
        self.onSaved = onSaved
        _values = State(initialValue: Array(repeating: "", count: fields.count))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(fields.indices, id: \.self) { i in
                        TextField(fields[i].label, text: Binding(
                            get: { values[i] },
                            set: { values[i] = $0 }
                        ))
                        .keyboardType(fields[i].keyboard)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    }
                } header: {
                    Text(title)
                }
                if let errorMessage {
                    Text(errorMessage).foregroundStyle(Ledger.accent)
                }
            }
            .ledgerBackground()
            .scrollIndicators(.hidden)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(isBusy || values.contains(where: { $0.trimmingCharacters(in: .whitespaces).isEmpty }))
                }
            }
        }
    }

    private func save() async {
        isBusy = true; errorMessage = nil
        do {
            let result = try await submit(values.map { $0.trimmingCharacters(in: .whitespaces) })
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

struct AddNoteSheet: View {
    @EnvironmentObject var api: APIClient
    var onSaved: () -> Void
    var body: some View {
        FieldSheet(title: "Add Note",
                   fields: [("Bundle ID", .default, false), ("Note text", .default, false)],
                   submit: { v in try await api.addNote(bundle: v[0], text: v[1]) }, onSaved: onSaved)
    }
}

struct AddPinSheet: View {
    @EnvironmentObject var api: APIClient
    var onSaved: () -> Void
    var body: some View {
        FieldSheet(title: "Add Pin",
                   fields: [("Bundle ID", .default, false), ("Version", .default, false)],
                   submit: { v in try await api.addPin(bundle: v[0], version: v[1]) }, onSaved: onSaved)
    }
}

struct AddAliasSheet: View {
    @EnvironmentObject var api: APIClient
    var onSaved: () -> Void
    var body: some View {
        FieldSheet(title: "Add Alias",
                   fields: [("Short (e.g. yt)", .default, false), ("Full search term", .default, false)],
                   submit: { v in try await api.addAlias(short: v[0], full: v[1]) }, onSaved: onSaved)
    }
}

struct AddTfWatchSheet: View {
    @EnvironmentObject var api: APIClient
    var onSaved: () -> Void
    var body: some View {
        FieldSheet(title: "Watch TestFlight",
                   fields: [("testflight.apple.com/join/…", .URL, false)],
                   submit: { v in try await api.addTfWatch(url: v[0]) }, onSaved: onSaved)
    }
}

struct AddSourceSheet: View {
    @EnvironmentObject var api: APIClient
    var onSaved: () -> Void
    var body: some View {
        FieldSheet(title: "Add Source",
                   fields: [("Name", .default, false), ("Feed URL", .URL, false), ("Emoji", .default, false)],
                   submit: { v in try await api.addSource(name: v[0], url: v[1], emoji: v[2]) }, onSaved: onSaved)
    }
}
