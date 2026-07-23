import SwiftUI

struct SignInstallView: View {
    @EnvironmentObject var api: APIClient
    @State private var cert: CertInfo?
    @State private var pickerActive = false

    @State private var ipaUrl: String
    @State private var appName = ""
    @State private var isUploading = false
    @State private var uploadedName: String?

    @State private var step = 1
    @State private var options = SignOptions()
    @State private var isBusy = false
    @State private var statusNote: String?
    @State private var errorMessage: String?

    init(prefillURL: String = "") {
        _ipaUrl = State(initialValue: prefillURL)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let cert {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SIGNING WITH").font(Ledger.heading(10, weight: .bold)).tracking(0.6).foregroundColor(Ledger.ok)
                            Text(cert.name ?? "configured").font(Ledger.mono(13)).foregroundColor(Ledger.text)
                            if let expiry = cert.expiry {
                                Text("Expires \(expiry)").font(Ledger.body(11)).foregroundColor(Ledger.textSecondary)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Ledger.okBg)
                        .overlay(Rectangle().stroke(Ledger.ok, lineWidth: 1))
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No signing certificate configured").font(Ledger.body(13)).foregroundColor(Ledger.accent)
                            Text("Add one in Settings first.").font(Ledger.body(11)).foregroundColor(Ledger.textSecondary)
                        }
                        .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                        .overlay(Rectangle().stroke(Ledger.divider, lineWidth: 1))
                    }

                    if step == 1 { stepOne } else { stepTwo }

                    if let statusNote {
                        Text(statusNote).foregroundColor(Ledger.ok).font(Ledger.body(13))
                    }
                    if let errorMessage {
                        Text(errorMessage).foregroundColor(Ledger.accent).font(Ledger.body(13))
                    }
                }
                .padding(16)
            }
            .ledgerBackground()
            .navigationTitle("Sign & Install")
            .navigationBarTitleDisplayMode(.inline)
            .task { await loadCert() }
            .sheet(isPresented: $pickerActive) {
                DocumentPicker { url in pickerActive = false; Task { await uploadPicked(url: url) } }
            }
        }
    }

    @ViewBuilder
    private var stepOne: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Step 1 — Add the IPA").font(Ledger.heading(16, weight: .semibold)).foregroundColor(Ledger.text)
            Text("Pick a file, or paste a direct download URL.").font(Ledger.body(12)).foregroundColor(Ledger.textSecondary)

            Button { pickerActive = true } label: {
                VStack(spacing: 6) {
                    if isUploading { ProgressView() }
                    else {
                        Glyph(.download, size: 22, color: Ledger.textSecondary)
                        Text(uploadedName ?? "Tap to choose a file").font(Ledger.body(14))
                    }
                }
                .frame(maxWidth: .infinity).padding(.vertical, 28)
            }
            .buttonStyle(.plain)
            .foregroundColor(Ledger.textSecondary)
            .overlay(Rectangle().strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5])).foregroundColor(Ledger.divider))

            Text("— or paste a URL —").font(Ledger.body(11)).foregroundColor(Ledger.textTertiary)
                .frame(maxWidth: .infinity, alignment: .center)

            TextField("https://…/app.ipa", text: $ipaUrl)
                .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                .font(Ledger.mono(13))
                .padding(10).overlay(Rectangle().stroke(Ledger.divider, lineWidth: 1))

            Text("App name (optional)").font(Ledger.body(12)).foregroundColor(Ledger.textSecondary)
            TextField("My App", text: $appName)
                .font(Ledger.body(14))
                .padding(10).overlay(Rectangle().stroke(Ledger.divider, lineWidth: 1))

            Button("Next — options →") { step = 2 }
                .buttonStyle(LedgerPrimaryButtonStyle())
                .disabled(resolvedUrl.isEmpty)
        }
    }

    @ViewBuilder
    private var stepTwo: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Step 2 — Options").font(Ledger.heading(16, weight: .semibold)).foregroundColor(Ledger.text)

            HStack(spacing: 0) {
                segment("Speed", isOn: options.compress == "speed") { options.compress = "speed" }
                segment("Size", isOn: options.compress == "size") { options.compress = "size" }
            }
            .overlay(Rectangle().stroke(Ledger.divider, lineWidth: 1))

            LedgerToggleRow(label: "Remove unsupported UI", isOn: $options.rm_uisupported)
            LedgerToggleRow(label: "Set minimum OS", isOn: $options.set_minos)
            LedgerToggleRow(label: "Remove plug-ins", isOn: $options.rm_plugins)
            LedgerToggleRow(label: "Remove watch app", isOn: $options.rm_watch)
            LedgerToggleRow(label: "Remove URL scheme", isOn: $options.rm_urlscheme)
            LedgerToggleRow(label: "Document browser", isOn: $options.doc_browser)
            LedgerToggleRow(label: "Remove provisioning", isOn: $options.rm_provision)

            HStack(spacing: 8) {
                Button("Back") { step = 1 }.buttonStyle(LedgerOutlineButtonStyle()).frame(maxWidth: 110)
                Button(isBusy ? "Signing…" : "Sign") { Task { await sign() } }
                    .buttonStyle(LedgerPrimaryButtonStyle())
                    .disabled(isBusy || cert == nil)
            }
        }
    }

    private func segment(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(Ledger.heading(12, weight: .bold)).tracking(0.4)
                .frame(maxWidth: .infinity).padding(.vertical, 9)
                .foregroundColor(isOn ? Ledger.bg : Ledger.textSecondary)
                .background(isOn ? Ledger.text : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private var resolvedUrl: String {
        if let uploadedName, !uploadedName.isEmpty { return uploadedUrl }
        return ipaUrl.trimmingCharacters(in: .whitespaces)
    }
    @State private var uploadedUrl = ""

    private func loadCert() async { cert = try? await api.certs().certs.first }

    private func uploadPicked(url: URL) async {
        isUploading = true; errorMessage = nil
        guard url.startAccessingSecurityScopedResource() else { errorMessage = "Couldn't access the picked file."; isUploading = false; return }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let data = try Data(contentsOf: url)
            let uploaded = try await api.uploadFile(data: data, filename: url.lastPathComponent)
            uploadedUrl = uploaded.url
            uploadedName = uploaded.name
            if appName.isEmpty { appName = url.deletingPathExtension().lastPathComponent }
        } catch { errorMessage = error.localizedDescription }
        isUploading = false
    }

    private func sign() async {
        isBusy = true; errorMessage = nil; statusNote = nil
        do {
            let name = appName.isEmpty ? (URL(string: resolvedUrl)?.lastPathComponent ?? "app") : appName
            let result = try await api.sign(ipaUrl: resolvedUrl, ipaName: name, options: options)
            if result.ok {
                statusNote = result.note ?? "Signing queued — check Library › Signed shortly."
                step = 1
                ipaUrl = ""; appName = ""; uploadedName = nil; uploadedUrl = ""
            } else { errorMessage = result.error ?? "Sign request failed." }
        } catch { errorMessage = error.localizedDescription }
        isBusy = false
    }
}
