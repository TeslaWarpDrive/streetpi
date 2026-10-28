import SwiftUI

/// Settings, beside the bell. A round icon, solid when motion is held.
struct SettingsChromeButton: View {
    var action: () -> Void

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.afterglowGate) private var gate
    /// The circle grows with the symbol, so large text never spills past it.
    @ScaledMetric(relativeTo: .body) private var side: CGFloat = 44

    var body: some View {
        let labeled = Button("Settings", systemImage: "gearshape", action: action)
            .labelStyle(.iconOnly)
            .font(.body)
            .foregroundStyle(palette.ink)
            .frame(width: side, height: side)
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
