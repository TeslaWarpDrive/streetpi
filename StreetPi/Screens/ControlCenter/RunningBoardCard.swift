import StreetPiCore
import SwiftUI

struct RunningBoardCard: View {
    var tile: RunningTile
    var onOpen: () -> Void

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        Button(action: onOpen) {
            BoardPanel {
                VStack(alignment: .leading, spacing: AfterglowShape.line) {
                    Text("Running for")
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
        .accessibilityLabel("Running for \(tile.figure). \(tile.line)")
    }
}
