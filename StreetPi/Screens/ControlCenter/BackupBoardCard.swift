import StreetPiCore
import SwiftUI

struct BackupBoardCard: View {
    var tile: BackupTile
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            BoardPanel {
                CompactFact(title: "Backups", value: tile.figure, tone: tile.tone)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Backups, \(tile.figure). \(tile.line)")
    }
}
