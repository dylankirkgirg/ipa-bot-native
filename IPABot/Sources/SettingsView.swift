import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var api: APIClient
    var forceOnboarding: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                if forceOnboarding {
                    Section {
                        Text("Point this at your ipa-bot deployment. Both fields are required before anything else works.")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Server") {
                    TextField("Base URL", text: $api.baseURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("X-Inject-Secret", text: $api.secret)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                if api.isConfigured {
                    Section {
                        Label("Configured", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}
