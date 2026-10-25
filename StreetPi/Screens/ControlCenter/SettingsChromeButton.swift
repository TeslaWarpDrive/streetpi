import SwiftUI

/// Settings, beside the bell. Solid when motion is held, so the gear still shows in a snapshot.
struct SettingsChromeButton: View {
    var action: () -> Void

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.afterglowGate) private var gate

    var body: some View {
        let labeled = Button("Settings", systemImage: "gearshape", action: action)
            .labelStyle(.iconOnly)
            .font(AfterglowType.label)
            .foregroundStyle(palette.ink)
            .frame(minWidth: 44, minHeight: 44)
            .padding(.horizontal, 12)
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
