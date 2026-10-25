import SwiftUI

/// The House bell. The count sits beside the icon, so it never covers the symbol.
struct AlertsBell: View {
    var count: Int
    var action: () -> Void

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.afterglowGate) private var gate

    var body: some View {
        let labeled = button
        Group {
            if gate.usesSolidPlate {
                labeled
                    .background(palette.panelRaised, in: Capsule())
                    .overlay { Capsule().strokeBorder(palette.hairlineInteractive, lineWidth: 1) }
            } else if #available(iOS 26, *) {
                labeled.glassEffect(.regular.interactive(), in: Capsule())
            } else {
                labeled
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay { Capsule().strokeBorder(palette.hairlineInteractive, lineWidth: 1) }
            }
        }
    }

    private var spoken: String {
        count == 0 ? "Alerts" : "Alerts, \(count)"
    }

    private var button: some View {
        Button(action: action) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    mark
                    countLabel
                }
                VStack(alignment: .leading, spacing: 4) {
                    mark
                    countLabel
                }
            }
            .font(AfterglowType.label)
            .foregroundStyle(palette.ink)
            .frame(minWidth: 44, minHeight: 44)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(spoken)
    }

    private var mark: some View {
        Image(systemName: "bell")
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var countLabel: some View {
        if count > 0 {
            Text("\(count)")
                .font(.body.monospacedDigit())
                .foregroundStyle(palette.ground)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(palette.problem, in: Capsule())
                .accessibilityHidden(true)
        }
    }
}
