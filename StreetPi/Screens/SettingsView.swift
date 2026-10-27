import StreetPiCore
import SwiftUI

struct SettingsView: View {
    var theme: StreetTheme
    @Binding var piHost: String
    var hostNote: String?
    var onCommitHost: () -> Void
    var onSaved: () -> Void = {}
    var statusAddress: String = LiveEndpoints.house.uptimeKuma.absoluteString
    var statusSlug: String = "house"
    var onStatusPage: (String, String) -> Void = { _, _ in }

    @State private var address = LiveHostStore().piholeText()
    @State private var pin = LiveHostStore().pinText()
    @State private var note = ""
    @State private var pageAddress: String
    @State private var slug: String

    init(
        theme: StreetTheme,
        piHost: Binding<String>,
        hostNote: String?,
        onCommitHost: @escaping () -> Void,
        onSaved: @escaping () -> Void = {},
        statusAddress: String = LiveEndpoints.house.uptimeKuma.absoluteString,
        statusSlug: String = "house",
        onStatusPage: @escaping (String, String) -> Void = { _, _ in }
    ) {
        self.theme = theme
        self._piHost = piHost
        self.hostNote = hostNote
        self.onCommitHost = onCommitHost
        self.onSaved = onSaved
        self.statusAddress = statusAddress
        self.statusSlug = statusSlug
        self.onStatusPage = onStatusPage
        _address = State(initialValue: LiveHostStore().piholeText())
        _pin = State(initialValue: LiveHostStore().pinText())
        _note = State(initialValue: "")
        _pageAddress = State(initialValue: statusAddress)
        _slug = State(initialValue: statusSlug)
    }

    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ControlScreen(wide: sizeClass == .regular) {
            ControlTitle(
                title: "Settings",
                line: "Raspberry Pi Stats is the same app for everyone in the house.",
                theme: theme
            )
            ControlGrid {
                NumberTile(
                    label: "House",
                    number: "1",
                    line: "Nothing here is tied to a person.",
                    theme: theme
                )
                PlainTile(title: "Version", line: versionLine, theme: theme)
            }
            adBlocker
                .controlPlate(theme: theme)
            piAddress
            statusPage
        }
        .onAppear {
            let hosts = LiveHostStore()
            address = hosts.piholeText()
            pin = hosts.pinText()
            pageAddress = statusAddress
            slug = statusSlug
        }
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
                    .reportsLayout("page-end")
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
