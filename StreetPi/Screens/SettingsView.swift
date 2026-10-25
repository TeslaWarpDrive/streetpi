import StreetPiCore
import SwiftUI

struct SettingsView: View {
    var theme: StreetTheme
    var onSaved: () -> Void = {}

    @State private var address = LiveHostStore().piholeText()
    @State private var pin = LiveHostStore().pinText()
    @State private var note = ""

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
                adBlocker
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
        .onAppear {
            let hosts = LiveHostStore()
            address = hosts.piholeText()
            pin = hosts.pinText()
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

    private var versionLine: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        guard short.isEmpty == false, build.isEmpty == false else { return "Raspberry Pi Stats" }
        return "Version \(short) (\(build))"
    }
}
