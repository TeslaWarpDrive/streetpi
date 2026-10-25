import StreetPiCore
import SwiftUI

struct SettingsView: View {
    var theme: StreetTheme
    var endpoint: StatusPageEndpoint = .house
    var onEndpoint: (StatusPageEndpoint) -> Void = { _ in }

    @State private var host: String
    @State private var portText: String
    @State private var slug: String
    @State private var problem: String?

    init(
        theme: StreetTheme,
        endpoint: StatusPageEndpoint = .house,
        onEndpoint: @escaping (StatusPageEndpoint) -> Void = { _ in }
    ) {
        self.theme = theme
        self.endpoint = endpoint
        self.onEndpoint = onEndpoint
        _host = State(initialValue: endpoint.host)
        _portText = State(initialValue: String(endpoint.port))
        _slug = State(initialValue: endpoint.slug)
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
        .onDisappear(perform: commit)
    }

    private var statusPage: some View {
        VStack(alignment: .leading, spacing: Rhythm.line) {
            Text("Status page")
                .font(.title2.weight(.semibold))
                .foregroundStyle(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("The status page is on the home network. The slug starts as house.")
                .font(.body)
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            field("Host", text: $host, prompt: "192.168.1.78")
            field("Port", text: $portText, prompt: "3001")
            field("Slug", text: $slug, prompt: "house")
            Button("Save status page", action: commit)
                .font(.body.weight(.semibold))
                .foregroundStyle(theme.ink)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, Rhythm.line)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            if let problem {
                Text(problem)
                    .font(.body)
                    .foregroundStyle(theme.attention)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(problem)
            }
        }
    }

    private func field(_ title: String, text: Binding<String>, prompt: String) -> some View {
        VStack(alignment: .leading, spacing: Rhythm.tight) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(theme.secondary)
                .accessibilityHidden(true)
            TextField(title, text: text, prompt: Text(prompt).foregroundStyle(theme.tertiary))
                .font(.body)
                .foregroundStyle(theme.ink)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textFieldStyle(.plain)
                .padding(Rhythm.line)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .onSubmit(commit)
        }
    }

    private func commit() {
        let draft = StatusPageEndpoint(host: host, port: Int(portText) ?? 0, slug: slug)
        guard let clean = draft.cleaned() else {
            problem = "Use a host, a port, and a slug like house."
            return
        }
        problem = nil
        onEndpoint(clean)
    }

    private var versionLine: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        guard !short.isEmpty, !build.isEmpty else { return "Raspberry Pi Stats" }
        return "Version \(short) (\(build))"
    }
}
