import StreetPiCore
import SwiftUI

/// Pause lengths as pills. Each one goes through the existing plain-English confirm and Face ID.
struct PausePills: View {
    var enabled: Bool
    var onAction: (HouseholdAction) -> Void

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsCustom = false
    @State private var minutes = ""

    var body: some View {
        VStack(alignment: .leading, spacing: AfterglowShape.line) {
            if enabled {
                Text("Pause for")
                    .font(.headline)
                    .foregroundStyle(palette.ink)
                    .accessibilityAddTraits(.isHeader)
                pills
                if showsCustom {
                    custom
                }
            } else {
                Pill(title: "Turn blocking back on", spoken: "Turn ad blocking back on") {
                    onAction(.resumeAdBlocking)
                }
            }
        }
    }

    @ViewBuilder
    private var pills: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: AfterglowShape.tight) {
                choices
            }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: BoardColumns<EmptyView, EmptyView>.phoneGap) {
                    choices
                }
                Grid(horizontalSpacing: AfterglowShape.tight, verticalSpacing: AfterglowShape.tight) {
                    GridRow {
                        preset(PauseLength.presets[0])
                        preset(PauseLength.presets[1])
                    }
                    GridRow {
                        preset(PauseLength.presets[2])
                        customPill
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var choices: some View {
        ForEach(PauseLength.presets) { length in
            preset(length)
        }
        customPill
    }

    private func preset(_ length: PauseLength) -> some View {
        Pill(title: short(length), spoken: "Pause for \(length.title)") {
            onAction(.pauseAdBlocking(length))
        }
    }

    private var customPill: some View {
        Pill(title: "Custom", spoken: "Pause for a custom length") {
            showsCustom.toggle()
        }
    }

    private var custom: some View {
        VStack(alignment: .leading, spacing: AfterglowShape.tight) {
            TextField("Minutes", text: $minutes)
                .keyboardType(.numberPad)
                .font(.body.monospacedDigit())
                .foregroundStyle(palette.ink)
                .padding(AfterglowShape.line)
                .background(palette.panel, in: RoundedRectangle(cornerRadius: AfterglowShape.tile, style: .continuous))
                .accessibilityLabel("Minutes to pause")
            Pill(title: "Pause for this long", spoken: "Pause for a custom length") {
                guard let customLength else { return }
                onAction(.pauseAdBlocking(customLength))
            }
            .disabled(customLength == nil)
        }
    }

    private var customLength: PauseLength? {
        guard let value = Int(minutes.trimmingCharacters(in: .whitespaces)),
              value > 0, value <= Int.max / 60 else { return nil }
        return PauseLength(seconds: value * 60)
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
}

struct Pill: View {
    var title: String
    var spoken: String
    var action: () -> Void

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AfterglowShape.line)
                .padding(.vertical, AfterglowShape.line)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(palette.panel, in: Capsule())
                .overlay {
                    Capsule().strokeBorder(palette.hairline, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(spoken)
    }
}

