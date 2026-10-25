import StreetPiCore
import SwiftUI

struct SettingsView: View {
    var theme: StreetTheme
    var address: String
    var slug: String
    var onSave: (String, String) -> Void

    @State private var addressText: String
    @State private var slugText: String
    @State private var problem: String?

    init(
        theme: StreetTheme,
        address: String = LiveEndpoints.house.uptimeKuma.absoluteString,
        slug: String = "house",
        onSave: @escaping (String, String) -> Void = { _, _ in }
    ) {
        self.theme = theme
        self.address = address
        self.slug = slug
        self.onSave = onSave
        _addressText = State(initialValue: address)
        _slugText = State(initialValue: slug)
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
            field("Address", text: $addressText, prompt: "http://192.168.1.78:3001")
            field("Slug", text: $slugText, prompt: "house")
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
        let trimmedSlug = slugText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard LiveAddress.validated(addressText, schemes: ["http", "https"]) != nil else {
            problem = "Use a status page address on your home network."
            return
        }
        guard StatusPageEndpoint.isSlug(trimmedSlug) else {
            problem = "Use a slug like house."
            return
        }
        problem = nil
        onSave(addressText.trimmingCharacters(in: .whitespacesAndNewlines), trimmedSlug)
    }

    private var versionLine: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        guard !short.isEmpty, !build.isEmpty else { return "Raspberry Pi Stats" }
        return "Version \(short) (\(build))"
    }
}
