import SwiftUI
import StreetPiCore

struct PiholeSetupView: View {
    var theme: StreetTheme
    var wide: Bool
    var onSave: (String) -> Void
    var onCancel: () -> Void

    @State private var entry = ""

    private var certificate: PiholeCertificate { .houseFixture }

    var body: some View {
        DeskScroll(wide: wide) {
            Text("Set up this phone")
                .font(.system(.largeTitle, design: .rounded))
                .foregroundStyle(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("The app password is entered once and saved on this phone. Raspberry Pi Stats does not show it again.")
                .font(.body)
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            SecureField("App password", text: $entry)
                .textContentType(.password)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.body)
                .foregroundStyle(theme.ink)
            trustCard
            Button {
                let password = entry
                entry = ""
                onSave(password)
            } label: {
                Text("Trust this Pi and save the password")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                    .padding(Rhythm.line)
            }
            .buttonStyle(.plain)
            .foregroundStyle(theme.background)
            .background(theme.accent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .opacity(entry.isEmpty ? 0.45 : 1)
            .disabled(entry.isEmpty)
            Button("Cancel", action: onCancel)
                .font(.body.weight(.semibold))
                .foregroundStyle(theme.ink)
        }
    }

    private var trustCard: some View {
        DeskCard(theme: theme) {
            HStack(alignment: .firstTextBaseline, spacing: Rhythm.line) {
                Image(systemName: "lock.shield")
                    .font(.title3)
                    .foregroundStyle(theme.accent)
                    .accessibilityHidden(true)
                Text("Trust this Pi")
                    .font(.headline)
                    .foregroundStyle(theme.ink)
                    .accessibilityAddTraits(.isHeader)
            }
            Text(PiholeTrust.explanation(for: certificate))
                .font(.body)
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("The fingerprint is kept on this phone and checked for this Pi only.")
                .font(.subheadline)
                .foregroundStyle(theme.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

struct DNSProblemView: View {
    var problem: PiholeProblem
    var theme: StreetTheme
    var wide: Bool

    var body: some View {
        DeskScroll(wide: wide) {
            HStack(alignment: .firstTextBaseline, spacing: Rhythm.line) {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(theme.problem)
                    .accessibilityHidden(true)
                Text(problem.title)
                    .font(.system(.largeTitle, design: .rounded))
                    .foregroundStyle(theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
            }
            Text(problem.detail)
                .font(.body)
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch problem {
        case .offline: "wifi.slash"
        case .refused: "hand.raised"
        default: "exclamationmark.circle"
        }
    }
}
