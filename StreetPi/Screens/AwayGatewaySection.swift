import StreetPiCore
import SwiftUI

/// Settings > Away, the live road. The secret goes in once and never comes back out:
/// the fields empty on save, and from then on the screen only says it is saved.
/// Replace key opens empty fields over that saved pair. It does not reveal the secret.
struct AwayGatewaySection: View {
    var theme: StreetTheme
    var form: AwayGatewayForm

    @State private var address: String
    @State private var entry = AwaySectionDraft()
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
            TextField(
                "Gateway address",
                text: $address,
                prompt: Text("https://").foregroundStyle(theme.tertiary),
                axis: .vertical
            )
            .modifier(AwayFieldPlate(theme: theme, fill: theme.surface))
            .accessibilityLabel("Gateway address")
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
        .onAppear {
            entry.acknowledge(stamp: form.savedStamp())
        }
        .onChange(of: form.saved) { _, saved in
            if saved == false {
                replacingKey = false
            }
        }
        .onChange(of: entry.clientID) { _, _ in entry.noteTyping(stamp: form.savedStamp()) }
        .onChange(of: entry.secret) { _, _ in entry.noteTyping(stamp: form.savedStamp()) }
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
            AwayKeyFields(theme: theme, fill: theme.surface, clientID: $entry.clientID, secret: $entry.secret)
        }
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

    private func beginReplace() {
        entry.clientID = ""
        entry.secret = ""
        note = ""
        replacingKey = true
    }

    private func cancelReplace() {
        entry.clientID = ""
        entry.secret = ""
        note = ""
        replacingKey = false
    }

    private func save() {
        switch entry.save(
            address: address,
            replacing: replacingKey,
            stamp: form.savedStamp,
            onSave: form.onSave
        ) {
        case .kept:
            note = SettingsDraftSave.keptKeyNote
        case .wrote(let result):
            note = result.note
            if result == .saved {
                replacingKey = false
            }
        }
    }

    private func remove() {
        let result = form.onRemove()
        note = result == .saved ? "Removed." : result.note
        if result == .saved {
            address = ""
            entry.clientID = ""
            entry.secret = ""
            replacingKey = false
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
