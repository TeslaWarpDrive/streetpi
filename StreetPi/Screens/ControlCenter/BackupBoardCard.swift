import StreetPiCore
import SwiftUI

struct BackupBoardCard: View {
    var tile: BackupTile
    var onOpen: () -> Void

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        Button(action: onOpen) {
            BoardPanel(inset: 4) {
                HouseGlance(title: "Backups", symbol: "externaldrive.badge.timemachine") {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Backups. \(detail)")
    }

    /// The sample sentence stays off the tile. Live copy uses the status line.
    private var detail: String {
        if tile.line.contains("succeeded") || tile.figure == "Copied" {
            return "Last copy recorded"
        }
        if tile.line.isEmpty {
            return tile.figure
        }
        return tile.line
    }
}
