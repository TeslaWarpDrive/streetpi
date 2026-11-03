import StreetPiCore
import SwiftUI

struct SettingsView: View {
    var theme: StreetTheme
    var passwordSaved: Bool
    var onPasswordSetup: () -> Void
    var onSignOut: () -> Void
    @Binding var piHost: String
    var hostNote: String?
    var onCommitHost: () -> Void
    var onSaved: () -> Void = {}
    var statusAddress: String = LiveEndpoints.house.uptimeKuma.absoluteString
    var statusSlug: String = "house"
    var onStatusPage: (String, String) -> Void = { _, _ in }
    var mailboxAddress: String = ""
    var mailboxTokenSaved: Bool = false
    var onSaveMailbox: (String, String) -> MailboxSaveResult = { _, _ in .failed }
    var onRemoveMailbox: () -> MailboxSaveResult = { .failed }
    var gatewayForm = AwayGatewayForm()

    @State private var address: String
    @State private var pin: String
    @State private var note: String
    @State private var pageAddress: String
    @State private var slug: String
    @State private var keyDraft: AwayKeyDraft

    init(
        theme: StreetTheme,
        passwordSaved: Bool = false,
        onPasswordSetup: @escaping () -> Void = {},
        onSignOut: @escaping () -> Void = {},
        piHost: Binding<String>,
        hostNote: String?,
        onCommitHost: @escaping () -> Void,
        onSaved: @escaping () -> Void = {},
        statusAddress: String = LiveEndpoints.house.uptimeKuma.absoluteString,
        statusSlug: String = "house",
        onStatusPage: @escaping (String, String) -> Void = { _, _ in },
        mailboxAddress: String = "",
        mailboxTokenSaved: Bool = false,
        onSaveMailbox: @escaping (String, String) -> MailboxSaveResult = { _, _ in .failed },
        onRemoveMailbox: @escaping () -> MailboxSaveResult = { .failed },
        gatewayForm: AwayGatewayForm = AwayGatewayForm(),
        keyDraft: AwayKeyDraft = AwayKeyDraft()
    ) {
        self.theme = theme
        self.passwordSaved = passwordSaved
        self.onPasswordSetup = onPasswordSetup
        self.onSignOut = onSignOut
        self._piHost = piHost
        self.hostNote = hostNote
        self.onCommitHost = onCommitHost
        self.onSaved = onSaved
        self.statusAddress = statusAddress
        self.statusSlug = statusSlug
        self.onStatusPage = onStatusPage
        self.mailboxAddress = mailboxAddress
        self.mailboxTokenSaved = mailboxTokenSaved
        self.onSaveMailbox = onSaveMailbox
        self.onRemoveMailbox = onRemoveMailbox
        self.gatewayForm = gatewayForm
        _address = State(initialValue: LiveHostStore().piholeText())
        _pin = State(initialValue: LiveHostStore().pinText())
        _note = State(initialValue: "")
        _pageAddress = State(initialValue: statusAddress)
        _slug = State(initialValue: statusSlug)
        _keyDraft = State(initialValue: keyDraft)
    }

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.awayKeyNotice) private var awayKeyNotice

    var body: some View {
        ControlScreen(wide: sizeClass == .regular) {
            if keyDraft.showsForm(notice: awayKeyNotice) {
                RejectedKeyCard(message: awayKeyNotice, theme: theme, form: gatewayForm, draft: $keyDraft)
            } else if keyDraft.showsConfirmation(notice: awayKeyNotice) {
                keySavedLine
            }
            ControlTitle(
                title: "Settings",
                line: "Raspberry Pi Stats is the same app for everyone in the house.",
                theme: theme
            )
            VStack(alignment: .leading, spacing: Rhythm.line) {
                Text("About")
                    .font(.headline)
                    .foregroundStyle(theme.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(versionLine)
                    .font(.body.monospaced())
                    .foregroundStyle(theme.secondary)
                Text("No analytics. No tracking SDKs. Your app password stays in this phone's Keychain.")
                    .font(.body)
                    .foregroundStyle(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .controlPlate(theme: theme)
            VStack(alignment: .leading, spacing: Rhythm.line) {
                Text("Ad blocker password")
                    .font(.headline)
                    .foregroundStyle(theme.ink)
                    .accessibilityAddTraits(.isHeader)
                Label(
                    passwordSaved ? "Saved on this phone" : "Not saved",
                    systemImage: passwordSaved ? "checkmark.circle" : "key"
                )
                    .font(.body)
                    .foregroundStyle(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(passwordSaved ? "Replace app password" : "Set up app password", action: onPasswordSetup)
                    .frame(minHeight: 44, alignment: .leading)
                if passwordSaved {
                    Button("Sign out of ad blocker", action: onSignOut)
                        .frame(minHeight: 44, alignment: .leading)
                }
            }
            .tint(theme.accent)
            .controlPlate(theme: theme)
            adBlocker
                .controlPlate(theme: theme)
            piAddress
            statusPage
            AwayGatewaySection(theme: theme, form: gatewayForm)
            AwaySettingsSection(
                theme: theme,
                savedAddress: mailboxAddress,
                tokenSaved: mailboxTokenSaved,
                onSave: onSaveMailbox,
                onRemove: onRemoveMailbox
            )
        }
        .onAppear {
            let hosts = LiveHostStore()
            address = hosts.piholeText()
            pin = hosts.pinText()
            pageAddress = statusAddress
            slug = statusSlug
        }
        .onDisappear { keyDraft.saved = false }
        .onChange(of: awayKeyNotice) { _, notice in
            keyDraft.settle(notice: notice)
        }
        .onChange(of: keyDraft.showsForm(notice: awayKeyNotice)) {
            keyDraft.settle(notice: awayKeyNotice)
        }
    }

    private var keySavedLine: some View {
        Label(AwayKeyDraft.savedLine, systemImage: "checkmark.circle")
            .font(.body)
            .foregroundStyle(theme.ink)
            .fixedSize(horizontal: false, vertical: true)
            .controlPlate(theme: theme)
    }

    private var adBlocker: some View {
        VStack(alignment: .leading, spacing: Rhythm.line) {
            Text("Ad blocker")
                .font(.headline)
                .foregroundStyle(theme.ink)
                .accessibilityAddTraits(.isHeader)
            Text("The address is https on port 443. The security pin is checked against the ad blocker's certificate.")
                .font(.body)
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Address")
                .font(.subheadline)
                .foregroundStyle(theme.secondary)
            TextField("https://192.168.1.78/api", text: $address)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .font(.body)
                .foregroundStyle(theme.ink)
            Text("Security pin")
                .font(.subheadline)
                .foregroundStyle(theme.secondary)
            TextField("Security pin", text: $pin)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.body)
                .foregroundStyle(theme.ink)
            Button("Save ad blocker settings", action: save)
                .font(.body.weight(.semibold))
                .foregroundStyle(theme.accent)
                .frame(minHeight: 44, alignment: .leading)
            if note.isEmpty == false {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func save() {
        let hosts = LiveHostStore()
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard PiholeBaseAddress.endpoint(from: trimmedAddress) != nil else {
            note = "Use an https address on port 443, ending in /api."
            return
        }
        do {
            try hosts.save(
                pihole: trimmedAddress,
                netdata: hosts.netdataText(),
                uptimeKuma: hosts.uptimeKumaText()
            )
            try hosts.savePin(pin)
        } catch LiveHostError.invalidPin {
            note = "That pin does not look right."
            return
        } catch {
            note = "Those settings could not be saved on this phone."
            return
        }
        note = "Saved."
        onSaved()
    }

    private var piAddress: some View {
        VStack(alignment: .leading, spacing: Rhythm.tight) {
            Text("Pi address")
                .font(.headline)
                .foregroundStyle(theme.ink)
                .accessibilityAddTraits(.isHeader)
            TextField(
                "Pi address",
                text: $piHost,
                prompt: Text(LiveEndpoints.house.netdata.absoluteString).foregroundStyle(theme.tertiary)
            )
            .textFieldStyle(.plain)
            .font(.body)
            .foregroundStyle(theme.ink)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .keyboardType(.URL)
            .submitLabel(.done)
            .padding(Rhythm.line)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(theme.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(theme.hairline, lineWidth: 1)
                    }
            }
            .onSubmit(onCommitHost)
            .accessibilityLabel("Pi address")
            Text("Charts are read from this address on your home network. Nothing here signs in.")
                .font(.subheadline)
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let hostNote {
                Text(hostNote)
                    .font(.subheadline)
                    .foregroundStyle(theme.attention)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(action: onCommitHost) {
                Text("Save address")
                    .font(.body)
                    .foregroundStyle(theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 44, alignment: .leading)
                    .padding(.horizontal, Rhythm.line)
                    .padding(.vertical, 10)
                    .background { Capsule().fill(theme.surface) }
                    .overlay { Capsule().stroke(theme.hairline, lineWidth: 1) }
            }
            .buttonStyle(.plain)
        }
    }

    private var statusPage: some View {
        VStack(alignment: .leading, spacing: Rhythm.tight) {
            Text("Status page")
                .font(.headline)
                .foregroundStyle(theme.ink)
                .accessibilityAddTraits(.isHeader)
            Text("The house status page is on your home network. The slug starts as house.")
                .font(.subheadline)
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            TextField(
                "Status page address",
                text: $pageAddress,
                prompt: Text(LiveEndpoints.house.uptimeKuma.absoluteString).foregroundStyle(theme.tertiary)
            )
            .textFieldStyle(.plain)
            .font(.body)
            .foregroundStyle(theme.ink)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .keyboardType(.URL)
            .submitLabel(.next)
            .padding(Rhythm.line)
            .background { plate }
            .accessibilityLabel("Status page address")
            TextField("Slug", text: $slug, prompt: Text("house").foregroundStyle(theme.tertiary))
                .textFieldStyle(.plain)
                .font(.body)
                .foregroundStyle(theme.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .submitLabel(.done)
                .padding(Rhythm.line)
                .background { plate }
                .onSubmit(saveStatusPage)
                .accessibilityLabel("Status page slug")
            Button(action: saveStatusPage) {
                Text("Save status page")
                    .font(.body)
                    .foregroundStyle(theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minHeight: 44, alignment: .leading)
                    .padding(.horizontal, Rhythm.line)
                    .padding(.vertical, 10)
                    .background { Capsule().fill(theme.surface) }
                    .overlay { Capsule().stroke(theme.hairline, lineWidth: 1) }
            }
            .buttonStyle(.plain)
        }
    }

    private var plate: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(theme.surface)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(theme.hairline, lineWidth: 1)
            }
    }

    private func saveStatusPage() {
        onStatusPage(pageAddress, slug)
    }

    private var versionLine: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        guard short.isEmpty == false, build.isEmpty == false else { return "Raspberry Pi Stats" }
        return "Version \(short) (\(build))"
    }
}

/// What the rejected-key card has typed so far. Settings holds it, so a probe that clears the message
/// takes the message away and leaves the text. It stays in memory and goes when the save does.
struct AwayKeyDraft: Equatable {
    static let savedLine = "New key saved."

    var clientID = ""
    var secret = ""
    var note = ""
    var saved = false

    private var hasText: Bool {
        clientID.isEmpty == false || secret.isEmpty == false
    }

    func showsForm(notice: String?) -> Bool {
        notice != nil || hasText
    }

    func showsConfirmation(notice: String?) -> Bool {
        saved && showsForm(notice: notice) == false
    }

    /// A rejection after a save means the new key did not work, so "saved" must not come back later.
    /// A note about a form that has gone must not come back with the next one either.
    mutating func settle(notice: String?) {
        if notice != nil { saved = false }
        if showsForm(notice: notice) == false { note = "" }
    }

    mutating func save(with form: AwayGatewayForm) {
        guard AwayKeyReplace.canSave(replacing: true, clientID: clientID, secret: secret) else {
            note = AwayGatewaySaveResult.missingCredentials.note
            return
        }
        let result = form.onSave(form.address, clientID, secret)
        guard result == .saved else {
            note = result.note
            return
        }
        self = AwayKeyDraft(saved: true)
    }
}

/// Puts the way out first while the key is rejected. It scrolls with the page, so large text still reaches
/// every field. The away section below keeps the address, the switch, and Remove.
/// With no message, a probe cleared the rejection mid-typing, and the card waits for that text.
struct RejectedKeyCard: View {
    var message: String?
    var theme: StreetTheme
    var form: AwayGatewayForm
    @Binding var draft: AwayKeyDraft

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Rhythm.tight) {
            Label(message ?? "Replace away key", systemImage: message == nil ? "key" : "key.slash")
                .font((dynamicTypeSize.isAccessibilitySize ? Font.caption : .footnote).weight(.semibold))
                .foregroundStyle(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            AwayKeyFields(theme: theme, fill: theme.background, clientID: $draft.clientID, secret: $draft.secret)
            Button("Save new key", action: save)
                .font(.body.weight(.semibold))
                .foregroundStyle(theme.accent)
                .frame(minHeight: 44, alignment: .leading)
            if message == nil {
                Button("Cancel") { draft = AwayKeyDraft() }
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.ink)
                    .frame(minHeight: 44, alignment: .leading)
                    .accessibilityLabel("Cancel replacing the away key")
            }
            if draft.note.isEmpty == false {
                Text(draft.note)
                    .font(.subheadline)
                    .foregroundStyle(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .controlPlate(theme: theme)
    }

    func save() {
        draft.save(with: form)
        if draft.saved {
            AccessibilityNotification.Announcement(AwayKeyDraft.savedLine).post()
        }
    }
}
