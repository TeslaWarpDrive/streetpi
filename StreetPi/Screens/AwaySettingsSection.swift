import StreetPiCore
import SwiftUI

/// Settings > Away. The read token goes in once and never comes back out:
/// the field empties on save, and from then on the screen only says it is saved.
struct AwaySettingsSection: View {
    var theme: StreetTheme
    var savedAddress: String
    var tokenSaved: Bool
    var onSave: (String, String) -> MailboxSaveResult
    var onRemove: () -> MailboxSaveResult

    @State private var address: String
    @State private var token = ""
    @State private var note = ""

    init(
        theme: StreetTheme,
        savedAddress: String,
        tokenSaved: Bool,
        onSave: @escaping (String, String) -> MailboxSaveResult,
        onRemove: @escaping () -> MailboxSaveResult
    ) {
        self.theme = theme
        self.savedAddress = savedAddress
        self.tokenSaved = tokenSaved
        self.onSave = onSave
        self.onRemove = onRemove
        _address = State(initialValue: savedAddress)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Rhythm.tight) {
            Text("Away")
                .font(.headline)
                .foregroundStyle(theme.ink)
                .accessibilityAddTraits(.isHeader)
            Text("Away from home, this phone reads the Pi's latest numbers from your mailbox. It can look, not change.")
                .font(.subheadline)
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            addressField
            tokenRow
            saveButton
            if tokenSaved {
                Button("Remove", role: .destructive, action: remove)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.attention)
                    .frame(minHeight: 44, alignment: .leading)
                    .accessibilityLabel("Remove the mailbox from this phone")
            }
            if note.isEmpty == false {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: savedAddress) { _, saved in
            address = saved
        }
    }

    private var addressField: some View {
        TextField(
            "Mailbox address",
            text: $address,
            prompt: Text("https://").foregroundStyle(theme.tertiary),
            axis: .vertical
        )
        .textFieldStyle(.plain)
        .font(.body)
        .foregroundStyle(theme.ink)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled(true)
        .keyboardType(.URL)
        .padding(Rhythm.line)
        .background { plate }
        .accessibilityLabel("Mailbox address")
    }

    @ViewBuilder
    private var tokenRow: some View {
        if tokenSaved {
            Label("Saved", systemImage: "checkmark.circle")
                .font(.body)
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minHeight: 44, alignment: .leading)
                .accessibilityLabel("Read token saved on this phone")
        } else {
            SecureField(
                "Read token",
                text: $token,
                prompt: Text("Read token").foregroundStyle(theme.tertiary)
            )
            .textFieldStyle(.plain)
            .font(.body)
            .foregroundStyle(theme.ink)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .padding(Rhythm.line)
            .background { plate }
            .accessibilityLabel("Read token")
        }
    }

    private var saveButton: some View {
        Button(action: save) {
            Text("Save mailbox")
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
        .reportsLayout("page-end")
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
        let result = onSave(address, token)
        note = result.note
        if result == .saved {
            token = ""
        }
    }

    private func remove() {
        let result = onRemove()
        note = result == .saved ? "Removed." : result.note
        if result == .saved {
            address = ""
            token = ""
        }
    }
}
