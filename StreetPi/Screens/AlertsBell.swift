import SwiftUI

/// The House bell. A round icon. The count sits on the corner, off the symbol.
struct AlertsBell: View {
    var alertCount: Int
    var action: () -> Void

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.afterglowGate) private var gate
    /// The circle grows with the symbol, so large text never spills past it.
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 44

    var body: some View {
        let labeled = button
        Group {
            if gate.usesSolidPlate {
                labeled
                    .background(palette.panelRaised, in: Circle())
                    .overlay { Circle().strokeBorder(palette.hairlineInteractive, lineWidth: 1) }
            } else if #available(iOS 26, *) {
                labeled.glassEffect(.regular.interactive(), in: Circle())
            } else {
                labeled
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay { Circle().strokeBorder(palette.hairlineInteractive, lineWidth: 1) }
            }
        }
    }

    private var spoken: String {
        alertCount == 0 ? "Alerts" : "Alerts, \(alertCount)"
    }

    private var button: some View {
        Button(action: action) {
            Image(systemName: "bell")
                .font(.body)
                .foregroundStyle(palette.ink)
                .frame(width: side, height: side)
                .overlay(alignment: .topTrailing) {
                    countLabel
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(spoken)
    }

    @ViewBuilder
    private var countLabel: some View {
        if alertCount > 0 {
            Text("\(alertCount)")
                .font(.caption.bold())
                .foregroundStyle(palette.ground)
                .padding(.horizontal, 5)
                .padding(.vertical, 1)
                .background(palette.problem, in: Capsule())
                .offset(x: 4, y: -4)
                .accessibilityHidden(true)
        }
    }
}
