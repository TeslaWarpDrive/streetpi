import StreetPiCore
import SwiftUI

/// Settings > Away, the live road. The secret goes in once and never comes back out:
/// the fields empty on save, and from then on the screen only says it is saved.
struct AwayGatewaySection: View {
    var theme: StreetTheme
    var form: AwayGatewayForm

    @State private var address: String
    @State private var clientID = ""
    @State private var secret = ""
    @State private var note = ""

    init(theme: StreetTheme, form: AwayGatewayForm) {
        self.theme = theme
        self.form = form
        _address = State(initialValue: form.address)
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
        } else {
            field("Client id", text: $clientID, prompt: "Client id")
            SecureField(
                "Client secret",
                text: $secret,
                prompt: Text("Client secret").foregroundStyle(theme.tertiary)
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

    private func save() {
        let result = form.onSave(address, clientID, secret)
        note = result.note
        if result == .saved {
            clientID = ""
            secret = ""
        }
    }

    private func remove() {
        let result = form.onRemove()
        note = result == .saved ? "Removed." : result.note
        if result == .saved {
            address = ""
            clientID = ""
            secret = ""
        }
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
