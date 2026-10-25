import SwiftUI

struct SettingsView: View {
    var theme: StreetTheme
    @Binding var piHost: String
    var hostNote: String?
    var onCommitHost: () -> Void
    var statusAddress: String = LiveEndpoints.house.uptimeKuma.absoluteString
    var statusSlug: String = "house"
    var onStatusPage: (String, String) -> Void = { _, _ in }

    @State private var pageAddress: String
    @State private var slug: String

    init(
        theme: StreetTheme,
        piHost: Binding<String>,
        hostNote: String?,
        onCommitHost: @escaping () -> Void,
        statusAddress: String = LiveEndpoints.house.uptimeKuma.absoluteString,
        statusSlug: String = "house",
        onStatusPage: @escaping (String, String) -> Void = { _, _ in }
    ) {
        self.theme = theme
        self._piHost = piHost
        self.hostNote = hostNote
        self.onCommitHost = onCommitHost
        self.statusAddress = statusAddress
        self.statusSlug = statusSlug
        self.onStatusPage = onStatusPage
        _pageAddress = State(initialValue: statusAddress)
        _slug = State(initialValue: statusSlug)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Rhythm.block) {
                Text("Settings")
                    .font(.system(.largeTitle, design: .rounded))
                    .foregroundStyle(theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text("Raspberry Pi Stats is the same app for everyone in the house. Nothing here is tied to a person.")
                    .font(.body)
                    .foregroundStyle(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                address
                statusPage
                Text(versionLine)
                    .font(.subheadline)
                    .foregroundStyle(theme.secondary)
                    .accessibilityLabel(versionLine)
            }
            .padding(.horizontal, Rhythm.page)
            .padding(.bottom, Rhythm.page)
            .frame(maxWidth: 680, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
    }

    private var address: some View {
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
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
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
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
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
        guard !short.isEmpty, !build.isEmpty else { return "Raspberry Pi Stats" }
        return "Version \(short) (\(build))"
    }
}
