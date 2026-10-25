import StreetPiCore
import SwiftUI

/// Pause lengths. Each one opens the existing confirmation. Nothing is sent from here.
struct AdBlockerPauseBar: View {
    var blockingOn: Bool
    var onAction: (HouseholdAction) -> Void

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showCustom = false
    @State private var minutes = ""

    var body: some View {
        VStack(alignment: .leading, spacing: AfterglowShape.line) {
            Text(blockingOn ? "Pause" : "Blocking")
                .font(.headline)
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if blockingOn {
                choices
                if showCustom {
                    customField
                }
            } else {
                PauseChoiceButton(title: "Turn blocking back on", label: "Turn ad blocking back on") {
                    onAction(.resumeAdBlocking)
                }
            }
        }
    }

    private var choices: some View {
        AfterglowTileGrid(
            spacing: AfterglowShape.line,
            minimumColumnWidth: dynamicTypeSize.isAccessibilitySize ? 10_000 : 88,
            maximumColumns: dynamicTypeSize.isAccessibilitySize ? 1 : 4
        ) {
            ForEach(PauseLength.presets) { length in
                PauseChoiceButton(title: length.shortTitle, label: "Pause for \(length.title)") {
                    onAction(.pauseAdBlocking(length))
                }
            }
            PauseChoiceButton(title: "Custom", label: "Pause for a custom length") {
                showCustom.toggle()
            }
        }
    }

    private var customLength: PauseLength? {
        guard let value = Int(minutes.trimmingCharacters(in: .whitespaces)) else { return nil }
        return PauseLength(seconds: value * 60)
    }

    private var customField: some View {
        VStack(alignment: .leading, spacing: AfterglowShape.line) {
            Text("Custom")
                .font(.headline)
                .foregroundStyle(palette.ink)
            TextField("Minutes", text: $minutes)
                .keyboardType(.numberPad)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.body)
                .foregroundStyle(palette.ink)
            Button(action: pauseCustom) {
                Text("Pause for this long")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(customLength == nil ? palette.tertiary : palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
            .disabled(customLength == nil)
            .accessibilityLabel("Pause for a custom length")
        }
    }

    private func pauseCustom() {
        guard let customLength else { return }
        onAction(.pauseAdBlocking(customLength))
    }
}

struct PauseChoiceButton: View {
    var title: String
    var label: String
    var action: () -> Void

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(palette.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(palette.panelRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(palette.hairline, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
