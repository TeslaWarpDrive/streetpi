import StreetPiCore
import SwiftUI

struct DevicesBoardCard: View {
    var tile: DevicesTile
    var onOpen: () -> Void

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        Button(action: onOpen) {
            BoardPanel {
                VStack(alignment: .leading, spacing: AfterglowShape.line) {
                    Text("Devices")
                        .font(.subheadline)
                        .foregroundStyle(palette.secondary)
                    Text(tile.figure)
                        .font(.system(.title, design: .rounded).bold())
                        .foregroundStyle(palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(tile.line)
                        .font(.body)
                        .foregroundStyle(palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Devices, \(tile.figure). \(tile.line)")
    }
}
