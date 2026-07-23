import SwiftUI

struct SignInstallView: View {
    @EnvironmentObject var api: APIClient
    @State private var cert: CertInfo?
    @State private var pickerActive = false

    @State private var ipaUrl = ""
    @State private var appName = ""
    @State private var isUploading = false
    @State private var uploadedName: String?

    @State private var step = 1
    @State private var options = SignOptions()
    @State private var isBusy = false
    @State private var statusNote: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let cert {
                        WebCard {
                            Text("SIGNING WITH:")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(WebTheme.textSecondary)
                            Text(cert.name ?? "configured")
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(WebTheme.success)
                            if let expiry = cert.expiry {
                                Text("Expires: \(expiry)")
                                    .font(.caption)
                                    .foregroundStyle(WebTheme.textSecondary)
                            }
                        }
                        .background(WebTheme.successBg)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(WebTheme.successBorder, lineWidth: 1))
                    } else {
                        WebCard {
                            Label("No signing certificate configured", systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(WebTheme.warning)
                            Text("Add one in Settings first.")
                                .font(.caption).foregroundStyle(WebTheme.textSecondary)
                        }
                    }

                    if step == 1 {
                        stepOne
                    } else {
                        stepTwo
                    }

                    if let statusNote {
                        Text(statusNote).foregroundStyle(WebTheme.success).font(.subheadline)
                    }
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(WebTheme.danger).font(.subheadline)
                    }
                }
                .padding(16)
            }
            .webBackground()
            .navigationTitle("Sign & Install")
            .task { await loadCert() }
            .sheet(isPresented: $pickerActive) {
                DocumentPicker { url in
                    pickerActive = false
                    Task { await uploadPicked(url: url) }
                }
            }
        }
    }

    @ViewBuilder
    private var stepOne: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Step 1 — Add the IPA")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(WebTheme.textPrimary)
            Text("Pick a file, or paste a direct download URL.")
                .font(.caption).foregroundStyle(WebTheme.textSecondary)

            Button {
                pickerActive = true
            } label: {
                VStack(spacing: 6) {
                    if isUploading {
                        ProgressView()
                    } else {
                        Image(systemName: "shippingbox").font(.title2)
                        Text(uploadedName ?? "Tap to choose a file")
                            .font(.subheadline)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(WebTheme.textSecondary)
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5])).foregroundStyle(WebTheme.cardBorderStrong))

            Text("— or paste a URL —")
                .font(.caption2).foregroundStyle(WebTheme.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)

            TextField("https://…/app.ipa", text: $ipaUrl)
                .textFieldStyle(.plain)
                .padding(10)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .background(WebTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(WebTheme.cardBorder, lineWidth: 1))

            Text("App name (optional)").font(.caption).foregroundStyle(WebTheme.textSecondary)
            TextField("My App", text: $appName)
                .textFieldStyle(.plain)
                .padding(10)
                .background(WebTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(WebTheme.cardBorder, lineWidth: 1))

            Button("Next — options →") { step = 2 }
                .buttonStyle(WebPrimaryButtonStyle())
                .disabled(resolvedUrl.isEmpty)
        }
    }

    @ViewBuilder
    private var stepTwo: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Step 2 — Options")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(WebTheme.textPrimary)

            Picker("Compression", selection: $options.compress) {
                Text("Speed").tag("speed")
                Text("Size").tag("size")
            }
            .pickerStyle(.segmented)

            Toggle("Remove unsupported UI", isOn: $options.rm_uisupported)
            Toggle("Set minimum OS", isOn: $options.set_minos)
            Toggle("Remove plug-ins", isOn: $options.rm_plugins)
            Toggle("Remove watch app", isOn: $options.rm_watch)
            Toggle("Remove URL scheme", isOn: $options.rm_urlscheme)
            Toggle("Document browser", isOn: $options.doc_browser)
            Toggle("Remove provisioning", isOn: $options.rm_provision)

            HStack(spacing: 10) {
                Button("← Back") { step = 1 }
                    .buttonStyle(WebPrimaryButtonStyle(color: WebTheme.card))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(WebTheme.cardBorder, lineWidth: 1))
                Button(isBusy ? "Signing…" : "Sign") { Task { await sign() } }
                    .buttonStyle(WebPrimaryButtonStyle())
                    .disabled(isBusy || cert == nil)
            }
        }
        .tint(WebTheme.accent)
    }

    private var resolvedUrl: String {
        if let uploadedName, !uploadedName.isEmpty { return uploadedUrl }
        return ipaUrl.trimmingCharacters(in: .whitespaces)
    }
    @State private var uploadedUrl = ""

    private func loadCert() async {
        cert = try? await api.certs().certs.first
    }

    private func uploadPicked(url: URL) async {
        isUploading = true; errorMessage = nil
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Couldn't access the picked file."
            isUploading = false
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let data = try Data(contentsOf: url)
            let uploaded = try await api.uploadFile(data: data, filename: url.lastPathComponent)
            uploadedUrl = uploaded.url
            uploadedName = uploaded.name
            if appName.isEmpty { appName = url.deletingPathExtension().lastPathComponent }
        } catch {
            errorMessage = error.localizedDescription
        }
        isUploading = false
    }

    private func sign() async {
        isBusy = true; errorMessage = nil; statusNote = nil
        do {
            let name = appName.isEmpty ? (URL(string: resolvedUrl)?.lastPathComponent ?? "app") : appName
            let result = try await api.sign(ipaUrl: resolvedUrl, ipaName: name, options: options)
            if result.ok {
                statusNote = result.note ?? "Signing queued — check the Signed tab shortly."
                step = 1
                ipaUrl = ""; appName = ""; uploadedName = nil; uploadedUrl = ""
            } else {
                errorMessage = result.error ?? "Sign request failed."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isBusy = false
    }
}
