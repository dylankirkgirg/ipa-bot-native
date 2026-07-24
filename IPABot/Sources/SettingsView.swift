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
    @State private var isBusyAdvanced = false
    @State private var advancedNote: String?
    @State private var exportTarget: ShareTarget?
    @State private var restartingService: String?
    @State private var autosignOn = false
    @State private var isTogglingAutosign = false
    @State private var iosVersion = ""
    @State private var iosNote: String?
    @State private var isSavingIos = false
    @State private var decryptBot = ""
    @State private var isSavingDecryptBot = false

    private let restartableServices = ["finder", "relay", "inject", "botapi", "sniper"]

    private enum CertPart: Identifiable { case p12, profile
        var id: Int { self == .p12 ? 0 : 1 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Settings").font(Ledger.heading(26)).padding(.horizontal, 20).padding(.top, 14).padding(.bottom, 8)

                    if forceOnboarding {
                        Text("Point this at your ipa-bot deployment to get started.")
                            .font(Ledger.body(13)).foregroundColor(Ledger.textSecondary)
                            .padding(.horizontal, 20).padding(.bottom, 12)
                    }

                    LedgerSectionLabel(text: "Connection")
                    connectionSection

                    LedgerSectionLabel(text: "Signing certificate")
                    certSection

                    LedgerSectionLabel(text: "Appearance")
                    appearanceSection

                    if api.isConfigured {
                        LedgerSectionLabel(text: "Advanced")
                        advancedSection
                    }
                }
            }
            .ledgerBackground()
            .navigationBarHidden(true)
            .task { await loadCert() }
            .sheet(item: $pickerTarget) { target in
                DocumentPicker { url in
                    pickerTarget = nil
                    Task { await upload(url: url, part: target) }
                }
            }
            .sheet(item: $exportTarget) { target in ShareSheet(items: [target.url]) }
        }
    }

    private var connectionSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if api.isConfigured && !editingConnection {
                Button { editingConnection = true } label: {
                    HStack {
                        LedgerStatusDot(ok: true)
                        Text(hostLabel).font(Ledger.mono(13)).foregroundColor(Ledger.text)
                        Spacer()
                        Text("Change").font(Ledger.body(12)).foregroundColor(Ledger.textSecondary)
                    }
                }
                .buttonStyle(.plain)
                .padding(.vertical, 9)
                .overlay(alignment: .bottom) { Rectangle().fill(Ledger.dividerSoft).frame(height: 1) }
                .padding(.horizontal, 20)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Base URL", text: $api.baseURL)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .font(Ledger.mono(13))
                        .padding(10).overlay(Rectangle().stroke(Ledger.divider, lineWidth: 1))
                    SecureField("X-Inject-Secret", text: $api.secret)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .font(Ledger.mono(13))
                        .padding(10).overlay(Rectangle().stroke(Ledger.divider, lineWidth: 1))
                    if api.isConfigured {
                        Button("Done") { editingConnection = false }.buttonStyle(LedgerOutlineButtonStyle())
                    }
                    Text("HTTPS only — the secret is sent as a header on every request and stored in Keychain.")
                        .font(Ledger.body(11)).foregroundColor(Ledger.textTertiary)
                }
                .padding(.horizontal, 20).padding(.bottom, 12)
            }
        }
    }

    private var certSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let cert {
                LedgerKeyValueRow(key: "Certificate", value: cert.name ?? "configured", valueIsMono: false)
                if let expiry = cert.expiry { LedgerKeyValueRow(key: "Expires", value: expiry) }
                HStack {
                    LedgerStatusDot(ok: cert.has_profile == true)
                    Text(cert.has_profile == true ? "Provisioning profile on file" : "No provisioning profile")
                        .font(Ledger.body(13)).foregroundColor(Ledger.text)
                }
                .padding(.vertical, 9)
                .overlay(alignment: .bottom) { Rectangle().fill(Ledger.dividerSoft).frame(height: 1) }
            } else {
                Text("No signing certificate configured yet.").font(Ledger.body(13)).foregroundColor(Ledger.textSecondary)
                    .padding(.vertical, 9)
                    .overlay(alignment: .bottom) { Rectangle().fill(Ledger.dividerSoft).frame(height: 1) }
            }

            Button("Upload .p12") { pickerTarget = .p12 }
                .buttonStyle(LedgerOutlineButtonStyle())
                .disabled(isBusy || !api.isConfigured)
                .padding(.vertical, 4)
            Button("Upload Provisioning Profile") { pickerTarget = .profile }
                .buttonStyle(LedgerOutlineButtonStyle())
                .disabled(isBusy || !api.isConfigured)
                .padding(.vertical, 4)

            HStack {
                SecureField("Certificate password", text: $certPassword).font(Ledger.body(14))
                Button("Save") { Task { await savePassword() } }
                    .buttonStyle(LedgerOutlineButtonStyle()).frame(width: 80)
                    .disabled(isBusy || certPassword.isEmpty)
            }
            .padding(.vertical, 9)
            .overlay(alignment: .bottom) { Rectangle().fill(Ledger.dividerSoft).frame(height: 1) }

            LedgerToggleRow(label: "Auto-sign starred updates", isOn: Binding(
                get: { autosignOn },
                set: { newValue in Task { await toggleAutosign(newValue) } }
            ))
            .opacity(isTogglingAutosign || cert == nil ? 0.5 : 1)
            .disabled(isTogglingAutosign || cert == nil)

            if let statusNote {
                Text(statusNote).font(Ledger.body(12)).foregroundColor(isBusy ? Ledger.textSecondary : Ledger.ok)
                    .padding(.top, 6)
            }
            if let errorMessage {
                Text(errorMessage).font(Ledger.body(12)).foregroundColor(Ledger.accent).padding(.top, 6)
            }
            Text("Used to sign IPAs when you tap Sign or Inject. Same cert as /addcert on Telegram.")
                .font(Ledger.body(11)).foregroundColor(Ledger.textTertiary).padding(.top, 8)
        }
        .padding(.horizontal, 20).padding(.bottom, 12)
    }

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 0) {
                ForEach(AppTheme.allCases) { t in
                    Button { api.theme = t } label: {
                        Text(t.label.uppercased())
                            .font(Ledger.heading(11, weight: .bold)).tracking(0.4)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .foregroundColor(api.theme == t ? Ledger.bg : Ledger.textSecondary)
                            .background(api.theme == t ? Ledger.text : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
            }
            .overlay(Rectangle().stroke(Ledger.divider, lineWidth: 1))

            NavigationLink { ReorderTabsView() } label: {
                HStack {
                    Text("Reorder tabs").font(Ledger.body(14)).foregroundColor(Ledger.text)
                    Spacer()
                    Glyph(.chevronRight, size: 13, color: Ledger.textTertiary)
                }
            }
            .padding(.vertical, 9)
            .overlay(alignment: .bottom) { Rectangle().fill(Ledger.dividerSoft).frame(height: 1) }

            HStack {
                Text("Your iOS version").font(Ledger.body(14)).foregroundColor(Ledger.text)
                Spacer()
                TextField("18.5", text: $iosVersion)
                    .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    .font(Ledger.mono(13)).frame(width: 70)
                Button("Save") { Task { await saveIosVersion() } }
                    .buttonStyle(LedgerOutlineButtonStyle())
                    .disabled(isSavingIos || iosVersion.isEmpty)
            }
            .padding(.vertical, 9)
            if let iosNote {
                Text(iosNote).font(Ledger.body(11)).foregroundColor(Ledger.textTertiary)
            } else {
                Text("Used to pick the right build variant for your device during search.")
                    .font(Ledger.body(11)).foregroundColor(Ledger.textTertiary)
            }
        }
        .padding(.horizontal, 20).padding(.bottom, 12)
    }

    private var advancedSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { Task { await runBackup() } } label: {
                HStack { Glyph(.share, size: 15, color: Ledger.textSecondary); Text("Back up now").font(Ledger.body(14)).foregroundColor(Ledger.text) }
            }
            .disabled(isBusyAdvanced)
            .padding(.vertical, 9)
            .overlay(alignment: .bottom) { Rectangle().fill(Ledger.dividerSoft).frame(height: 1) }

            Button { Task { await runExport() } } label: {
                HStack { Glyph(.download, size: 15, color: Ledger.textSecondary); Text("Export state (.json)").font(Ledger.body(14)).foregroundColor(Ledger.text) }
            }
            .disabled(isBusyAdvanced)
            .padding(.vertical, 9)
            .overlay(alignment: .bottom) { Rectangle().fill(Ledger.dividerSoft).frame(height: 1) }

            Button { Task { await runTweakCheck() } } label: {
                HStack {
                    Glyph(.gear, size: 15, color: Ledger.textSecondary)
                    Text("Check tweak repos").font(Ledger.body(14)).foregroundColor(Ledger.text)
                }
            }
            .disabled(isBusyAdvanced)
            .padding(.vertical, 9)
            .overlay(alignment: .bottom) { Rectangle().fill(Ledger.dividerSoft).frame(height: 1) }

            ForEach(restartableServices, id: \.self) { service in
                Button { Task { await restart(service) } } label: {
                    HStack {
                        Glyph(.refresh, size: 15, color: Ledger.textSecondary)
                        Text("Restart \(service)").font(Ledger.body(14)).foregroundColor(Ledger.text)
                        Spacer()
                        if restartingService == service { ProgressView() }
                    }
                }
                .disabled(isBusyAdvanced)
                .padding(.vertical, 9)
                .overlay(alignment: .bottom) { Rectangle().fill(Ledger.dividerSoft).frame(height: 1) }
            }

            HStack {
                Text("Decrypt relay bot").font(Ledger.body(14)).foregroundColor(Ledger.text)
                Spacer()
                TextField("@SomeBot", text: $decryptBot)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .multilineTextAlignment(.trailing)
                    .font(Ledger.mono(12)).frame(width: 120)
                Button("Save") { Task { await saveDecryptBot() } }
                    .buttonStyle(LedgerOutlineButtonStyle())
                    .disabled(isSavingDecryptBot || decryptBot.isEmpty)
            }
            .padding(.vertical, 9)
            .overlay(alignment: .bottom) { Rectangle().fill(Ledger.dividerSoft).frame(height: 1) }

            if let advancedNote {
                Text(advancedNote).font(Ledger.body(12)).foregroundColor(Ledger.textSecondary).padding(.top, 8)
            }
            Text("Backup/export mirror /backup and /export on Telegram. Restart bounces one on-box service.")
                .font(Ledger.body(11)).foregroundColor(Ledger.textTertiary).padding(.top, 8)
        }
        .padding(.horizontal, 20).padding(.bottom, 24)
    }

    private var hostLabel: String { URL(string: api.baseURL)?.host ?? api.baseURL }

    private func loadCert() async {
        do { cert = try await api.certs().certs.first } catch {}
        let status = try? await api.status()
        autosignOn = status?.autosign ?? false
        iosVersion = status?.iosVersion ?? ""
        decryptBot = (try? await api.decryptBot().bot) ?? ""
    }

    private func saveDecryptBot() async {
        isSavingDecryptBot = true; advancedNote = nil
        do {
            let result = try await api.setDecryptBot(decryptBot)
            advancedNote = result.ok ? "Decrypt bot set to @\(result.bot ?? decryptBot)." : (result.error ?? "Couldn't save.")
        } catch { advancedNote = error.localizedDescription }
        isSavingDecryptBot = false
    }

    private func saveIosVersion() async {
        isSavingIos = true; iosNote = nil
        do {
            let result = try await api.setIosVersion(iosVersion)
            iosNote = result.ok ? "Saved." : (result.error ?? "Couldn't save.")
        } catch { iosNote = error.localizedDescription }
        isSavingIos = false
    }

    private func toggleAutosign(_ on: Bool) async {
        isTogglingAutosign = true
        do {
            let result = try await api.setAutosign(on)
            if result.ok { autosignOn = on } else { advancedNote = result.error ?? "Couldn't update auto-sign." }
        } catch { advancedNote = error.localizedDescription }
        isTogglingAutosign = false
    }

    private func upload(url: URL, part: CertPart) async {
        isBusy = true; errorMessage = nil; statusNote = nil
        defer { isBusy = false }
        guard url.startAccessingSecurityScopedResource() else { errorMessage = "Couldn't access the picked file."; return }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let data = try Data(contentsOf: url)
            let uploaded = try await api.uploadFile(data: data, filename: url.lastPathComponent)
            let result = try await api.submitCertPart(part: part == .p12 ? "p12" : "profile", ipaUrl: uploaded.url, fileName: uploaded.name)
            if result.ok {
                statusNote = (part == .p12 ? ".p12" : "Profile") + " uploaded."
                await loadCert()
            } else { errorMessage = result.error ?? "Upload failed." }
        } catch { errorMessage = error.localizedDescription }
    }

    private func savePassword() async {
        isBusy = true; errorMessage = nil; statusNote = nil
        do {
            let result = try await api.submitCertPart(part: "password", password: certPassword)
            if result.ok { statusNote = "Password saved."; certPassword = "" } else { errorMessage = result.error ?? "Couldn't save password." }
        } catch { errorMessage = error.localizedDescription }
        isBusy = false
    }

    private func runBackup() async {
        isBusyAdvanced = true; advancedNote = nil
        do {
            let result = try await api.backupNow()
            advancedNote = result.ok ? "Backup delivered." : (result.error ?? "Backup failed.")
        } catch { advancedNote = error.localizedDescription }
        isBusyAdvanced = false
    }

    private func runExport() async {
        isBusyAdvanced = true; advancedNote = nil
        do { exportTarget = ShareTarget(url: try await api.exportDump()) } catch { advancedNote = error.localizedDescription }
        isBusyAdvanced = false
    }

    private func runTweakCheck() async {
        isBusyAdvanced = true; advancedNote = nil
        do {
            let result = try await api.tweakCheck()
            advancedNote = result.broken.isEmpty
                ? "All \(result.total) tweak repos are live."
                : "\(result.broken.count) of \(result.total) tweak repos broken."
        } catch { advancedNote = error.localizedDescription }
        isBusyAdvanced = false
    }

    private func restart(_ service: String) async {
        isBusyAdvanced = true; restartingService = service; advancedNote = nil
        do {
            let result = try await api.restartService(service)
            advancedNote = result.ok ? "\(service) restarted." : (result.error ?? "Restart failed.")
        } catch { advancedNote = error.localizedDescription }
        isBusyAdvanced = false
        restartingService = nil
    }
}
