import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var api: APIClient
    var forceOnboarding: Bool = false

    @State private var cert: CertInfo?
    @State private var certPassword = ""
    @State private var isBusy = false
    @State private var statusNote: String?
    @State private var errorMessage: String?
    @State private var pickerTarget: CertPart?
    @State private var editingConnection = false

    private enum CertPart: Identifiable { case p12, profile
        var id: Int { self == .p12 ? 0 : 1 }
    }

    var body: some View {
        NavigationStack {
            Form {
                if forceOnboarding {
                    Section {
                        Label("Point this at your ipa-bot deployment to get started.", systemImage: "arrow.down.circle")
                            .foregroundStyle(.secondary)
                    }
                }

                if api.isConfigured && !editingConnection {
                    Section {
                        Button {
                            editingConnection = true
                        } label: {
                            HStack {
                                Label("Connected — \(hostLabel)", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Spacer()
                                Text("Change").foregroundStyle(.secondary)
                            }
                        }
                    }
                } else {
                    Section {
                        TextField("Base URL", text: $api.baseURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        SecureField("X-Inject-Secret", text: $api.secret)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        if api.isConfigured {
                            Button("Done") { editingConnection = false }
                        }
                    } header: {
                        Label("Connection", systemImage: "server.rack")
                    } footer: {
                        Text("HTTPS only — the secret is sent as a header on every request and stored in Keychain.")
                    }
                }

                Section {
                    if let cert {
                        LabeledContent("Certificate", value: cert.name ?? "configured")
                        if let expiry = cert.expiry {
                            LabeledContent("Expires", value: expiry)
                        }
                        Label(cert.has_profile == true ? "Provisioning profile on file" : "No provisioning profile",
                              systemImage: cert.has_profile == true ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(cert.has_profile == true ? Color.green : Color.orange)
                    } else {
                        Text("No signing certificate configured yet.").foregroundStyle(.secondary)
                    }

                    Button {
                        pickerTarget = .p12
                    } label: {
                        Label("Upload .p12", systemImage: "doc.badge.plus")
                    }.disabled(isBusy || !api.isConfigured)

                    Button {
                        pickerTarget = .profile
                    } label: {
                        Label("Upload Provisioning Profile", systemImage: "doc.badge.plus")
                    }.disabled(isBusy || !api.isConfigured)

                    HStack {
                        SecureField("Certificate password", text: $certPassword)
                        Button("Save") { Task { await savePassword() } }
                            .disabled(isBusy || certPassword.isEmpty)
                    }

                    if let statusNote {
                        Label(statusNote, systemImage: isBusy ? "hourglass" : "checkmark.circle.fill")
                            .foregroundStyle(isBusy ? Color.secondary : Color.green)
                    }
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                } header: {
                    Label("Signing Certificate", systemImage: "signature")
                } footer: {
                    Text("Used to sign IPAs when you tap Sign or Inject. Same cert as /addcert on Telegram.")
                }

                Section {
                    Picker("Appearance", selection: $api.theme) {
                        ForEach(AppTheme.allCases) { t in
                            Text(t.label).tag(t)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Label("Appearance", systemImage: "circle.lefthalf.filled")
                }
            }
            .navigationTitle("Settings")
            .task { await loadCert() }
            .sheet(item: $pickerTarget) { target in
                DocumentPicker { url in
                    pickerTarget = nil
                    Task { await upload(url: url, part: target) }
                }
            }
        }
    }

    private var hostLabel: String {
        URL(string: api.baseURL)?.host ?? api.baseURL
    }

    private func loadCert() async {
        do {
            cert = try await api.certs().certs.first
        } catch {
            // no cert configured yet — not an error worth surfacing on load
        }
    }

    private func upload(url: URL, part: CertPart) async {
        isBusy = true; errorMessage = nil; statusNote = nil
        defer { isBusy = false }
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Couldn't access the picked file."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let data = try Data(contentsOf: url)
            let uploaded = try await api.uploadFile(data: data, filename: url.lastPathComponent)
            let result = try await api.submitCertPart(
                part: part == .p12 ? "p12" : "profile",
                ipaUrl: uploaded.url, fileName: uploaded.name
            )
            if result.ok {
                statusNote = (part == .p12 ? ".p12" : "Profile") + " uploaded."
                await loadCert()
            } else {
                errorMessage = result.error ?? "Upload failed."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func savePassword() async {
        isBusy = true; errorMessage = nil; statusNote = nil
        do {
            let result = try await api.submitCertPart(part: "password", password: certPassword)
            if result.ok {
                statusNote = "Password saved."
                certPassword = ""
            } else {
                errorMessage = result.error ?? "Couldn't save password."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isBusy = false
    }
}
