import StreetPiCore
import SwiftUI

/// Settings > Away, the live road. The secret goes in once and never comes back out:
/// the fields empty on save, and from then on the screen only says it is saved.
/// Replace key opens empty fields over that saved pair. It does not reveal the secret.
struct AwayGatewaySection: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    var theme: StreetTheme
    var form: AwayGatewayForm

    @State private var address: String
    @State private var clientID = ""
    @State private var secret = ""
    @State private var note = ""
    @State private var replacingKey: Bool

    init(theme: StreetTheme, form: AwayGatewayForm, replacingKey: Bool = false) {
        self.theme = theme
        self.form = form
        _address = State(initialValue: form.address)
        _replacingKey = State(initialValue: replacingKey)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Rhythm.tight) {
            Text("Away connection")
                .font(.headline)
                .foregroundStyle(theme.ink)
                .accessibilityAddTraits(.isHeader)
            Text("Away from home, this phone reaches the Pi through your gateway, so everything works the same.")
                .font(.subheadline)
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Toggle("Use away connection", isOn: enabledBinding)
                .font(.body)
                .foregroundStyle(theme.ink)
                .frame(minHeight: 44)
            field("Gateway address", text: $address, prompt: "https://")
                .keyboardType(.URL)
            credentials
            saveButton
            if replacingKey {
                Button("Cancel", action: cancelReplace)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.ink)
                    .frame(minHeight: 44, alignment: .leading)
                    .accessibilityLabel("Cancel replacing the gateway key")
            }
            if form.saved, replacingKey == false {
                Button("Replace key", action: beginReplace)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.ink)
                    .frame(minHeight: 44, alignment: .leading)
                    .accessibilityLabel("Replace the saved gateway key")
            }
            if form.saved {
                Button("Remove", role: .destructive, action: remove)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.attention)
                    .frame(minHeight: 44, alignment: .leading)
                    .accessibilityLabel("Remove the gateway from this phone")
            }
            if note.isEmpty == false {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: form.address) { _, saved in
            address = saved
        }
        .onChange(of: form.saved) { _, saved in
            if saved == false {
                replacingKey = false
            }
        }
    }

    private var enabledBinding: Binding<Bool> {
        Binding(get: { form.enabled }, set: { form.onEnabled($0) })
    }

    @ViewBuilder
    private var credentials: some View {
        if form.saved {
            Label("Saved", systemImage: "checkmark.circle")
                .font(.body)
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 44, alignment: .leading)
                .accessibilityLabel("Gateway client id and secret saved on this phone")
        }
        if AwayKeyReplace.showsFields(saved: form.saved, replacing: replacingKey) {
            field("Client id", text: $clientID, prompt: "Client id")
            if dynamicTypeSize.isAccessibilitySize {
                Text("Client secret")
                    .font(.body)
                    .foregroundStyle(theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)
            }
            SecureField(
                "Client secret",
                text: $secret,
                prompt: Text(dynamicTypeSize.isAccessibilitySize ? "" : "Client secret").foregroundStyle(theme.tertiary)
            )
            .textFieldStyle(.plain)
            .font(.body)
            .foregroundStyle(theme.ink)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .padding(Rhythm.line)
            .background { plate }
            .accessibilityLabel("Client secret")
        }
    }

    private func field(_ title: String, text: Binding<String>, prompt: String) -> some View {
        TextField(
            title,
            text: text,
            prompt: Text(prompt).foregroundStyle(theme.tertiary),
            axis: .vertical
        )
        .textFieldStyle(.plain)
        .font(.body)
        .foregroundStyle(theme.ink)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled(true)
        .padding(Rhythm.line)
        .background { plate }
        .accessibilityLabel(title)
    }

    private var saveButton: some View {
        Button(action: save) {
            Text("Save gateway")
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

    private var plate: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(theme.surface)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(theme.hairline, lineWidth: 1)
            }
    }

    private func beginReplace() {
        clientID = ""
        secret = ""
        note = ""
        replacingKey = true
    }

    private func cancelReplace() {
        clientID = ""
        secret = ""
        note = ""
        replacingKey = false
    }

    private func save() {
        guard AwayKeyReplace.canSave(replacing: replacingKey, clientID: clientID, secret: secret) else {
            note = AwayGatewaySaveResult.missingCredentials.note
            return
        }
        let result = form.onSave(address, clientID, secret)
        note = result.note
        if result == .saved {
            clientID = ""
            secret = ""
            replacingKey = false
        }
    }

    private func remove() {
        let result = form.onRemove()
        note = result == .saved ? "Removed." : result.note
        if result == .saved {
            address = ""
            clientID = ""
            secret = ""
            replacingKey = false
        }
    }
}

/// A saved gateway key stays masked until Replace key. The secret is never copied into the fields.
enum AwayKeyReplace {
    static func showsFields(saved: Bool, replacing: Bool) -> Bool {
        saved == false || replacing
    }

    /// An empty replacement would keep the saved secret, so both new values are required.
    static func canSave(replacing: Bool, clientID: String, secret: String) -> Bool {
        guard replacing else { return true }
        let id = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        return id.isEmpty == false && key.isEmpty == false
    }
}

/// The small "Away" chip while the app is live through the gateway. Chrome, so it may be glass.
struct AwayChip: View {
    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            Label(AwayCopy.awayChip, systemImage: "antenna.radiowaves.left.and.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(palette.ink)
                .padding(.horizontal, AfterglowShape.line)
                .padding(.vertical, AfterglowShape.tight)
                .modifier(AwayChipGlass())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(AwayCopy.awayChipSpoken)
        }
        .padding(.horizontal, AfterglowShape.line)
        .padding(.top, AfterglowShape.tight)
    }
}

private struct AwayChipGlass: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.glassEffect(.regular, in: Capsule())
        } else {
            content.background(.ultraThinMaterial, in: Capsule())
        }
    }
}
