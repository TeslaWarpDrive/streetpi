import SwiftUI
import StreetPiCore

struct PiholeSetupView: View {
    var theme: StreetTheme
    var wide: Bool
    var trustNote: String?
    var onSave: (String) -> Void
    var onCancel: () -> Void

    @State private var entry = ""

    private var certificate: PiholeCertificate { .houseFixture }

    var body: some View {
        ControlScreen(wide: wide) {
            ControlTitle(
                title: "Set up this phone",
                line: "The app password is entered once and saved on this phone. Raspberry Pi Stats does not show it again.",
                theme: theme
            )
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
                .frame(minHeight: 44, alignment: .leading)
        }
    }

    private var trustCard: some View {
        VStack(alignment: .leading, spacing: Rhythm.line) {
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
            Text(trustNote ?? PiholeTrust.explanation(for: certificate))
                .font(.body)
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("The fingerprint is kept on this phone and checked for this Pi only.")
                .font(.subheadline)
                .foregroundStyle(theme.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .controlPlate(theme: theme)
        .accessibilityElement(children: .combine)
    }
}

struct ActionNoticeBanner: View {
    var notice: ActionNotice
    var theme: StreetTheme

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Rhythm.line) {
            Image(systemName: notice.failed ? "exclamationmark.circle" : "checkmark.circle")
                .font(.title3)
                .foregroundStyle(notice.failed ? theme.problem : theme.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Rhythm.tight) {
                Text(notice.title)
                    .font(.headline)
                    .foregroundStyle(theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(notice.detail)
                    .font(.subheadline)
                    .foregroundStyle(theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Rhythm.line)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(theme.hairline, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}

struct DNSProblemView: View {
    var problem: PiholeProblem
    var theme: StreetTheme
    var wide: Bool
    var offersSetup = false
    var onSavePassword: () -> Void = {}
    var onTrustNewCertificate: () -> Void = {}
    var onKeepSavedPin: () -> Void = {}

    var body: some View {
        ControlScreen(wide: wide) {
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
            if problem == .certificateChanged {
                Button("Trust the new certificate", action: onTrustNewCertificate)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.accent)
                Button("Keep the saved pin", action: onKeepSavedPin)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.ink)
            }
            if offersSetup {
                Button("Set up this phone", action: onSavePassword)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(theme.accent)
            }
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
