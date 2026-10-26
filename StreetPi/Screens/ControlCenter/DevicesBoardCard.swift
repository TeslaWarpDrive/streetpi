import StreetPiCore
import SwiftUI

struct DevicesBoardCard: View {
    var tile: DevicesTile
    var onOpen: () -> Void

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        Button(action: onOpen) {
            BoardPanel {
                HouseGlance(title: "Devices", symbol: "ipad.and.iphone") {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Devices. \(detail)")
    }

    private var detail: String {
        guard let count = Int(tile.figure) else { return tile.line }
        if count == 1 {
            return "1 using the Pi"
        }
        return "\(count) using the Pi"
    }
}
