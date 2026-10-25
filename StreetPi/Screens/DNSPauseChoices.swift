import StreetPiCore
import SwiftUI

/// Pause lengths. Confirmation and Face ID stay on the existing action path. This sends no network call.
struct DNSPauseChoices: View {
    var desk: DNSDesk
    var theme: StreetTheme
    var onAction: (HouseholdAction) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var minutes = ""

    var body: some View {
        if desk.blocking.enabled {
            VStack(alignment: .leading, spacing: Rhythm.line) {
                Text("Pause for")
                    .font(.headline)
                    .foregroundStyle(theme.ink)
                    .accessibilityAddTraits(.isHeader)
                choices
                customPause
            }
        } else {
            DNSChoiceButton(
                title: "Turn blocking back on",
                label: "Turn ad blocking back on",
                theme: theme,
                action: { onAction(.resumeAdBlocking) }
            )
        }
    }

    @ViewBuilder
    private var choices: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Rhythm.line) {
                presets
            }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: Rhythm.line) {
                    presets
                }
                VStack(alignment: .leading, spacing: Rhythm.line) {
                    presets
                }
            }
        }
    }

    private var presets: some View {
        ForEach(PauseLength.presets) { length in
            DNSChoiceButton(
                title: short(length),
                label: "Pause for \(length.title)",
                theme: theme
            ) {
                onAction(.pauseAdBlocking(length))
            }
        }
    }

    private func short(_ length: PauseLength) -> String {
        switch length.seconds {
        case 30:
            "30 sec"
        case 300:
            "5 min"
        case 1_800:
            "30 min"
        default:
            length.title
        }
    }

    private var customLength: PauseLength? {
        guard let value = Int(minutes.trimmingCharacters(in: .whitespaces)) else { return nil }
        return PauseLength(seconds: value * 60)
    }

    private var customPause: some View {
        VStack(alignment: .leading, spacing: Rhythm.line) {
            Text("Custom")
                .font(.headline)
                .foregroundStyle(theme.ink)
            TextField("Minutes", text: $minutes)
                .keyboardType(.numberPad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.body)
                .foregroundStyle(theme.ink)
            DNSChoiceButton(
                title: "Pause for this long",
                label: "Pause for a custom length",
                theme: theme,
                enabled: customLength != nil
            ) {
                guard let customLength else { return }
                onAction(.pauseAdBlocking(customLength))
            }
        }
    }
}
