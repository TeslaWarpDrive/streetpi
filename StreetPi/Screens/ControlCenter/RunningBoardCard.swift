import StreetPiCore
import SwiftUI

struct RunningBoardCard: View {
    var tile: RunningTile
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            BoardPanel {
                CompactFact(title: "Running for", value: tile.figure, tone: nil)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Running for \(tile.figure). \(tile.line)")
    }
}
