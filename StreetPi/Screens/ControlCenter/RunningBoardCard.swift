import StreetPiCore
import SwiftUI

struct RunningBoardCard: View {
    var tile: RunningTile
    var onOpen: () -> Void

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        Button(action: onOpen) {
            BoardPanel {
                HouseGlance(title: "Running for", symbol: "clock") {
                    Text(tile.figure)
                        .font(.caption)
                        .foregroundStyle(palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Running for \(tile.figure). \(tile.line)")
    }
}
