import StreetPiCore
import SwiftUI

struct DevicesBoardCard: View {
    var tile: DevicesTile
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            BoardPanel {
                CompactFact(title: "Devices", value: tile.figure, tone: nil)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Devices, \(tile.figure). \(tile.line)")
    }
}
