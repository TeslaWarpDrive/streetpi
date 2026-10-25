import StreetPiCore
import SwiftUI

struct BackupBoardCard: View {
    var tile: BackupTile
    var onOpen: () -> Void

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        Button(action: onOpen) {
            BoardPanel {
                VStack(alignment: .leading, spacing: AfterglowShape.line) {
                    Text("Backups")
                        .font(.subheadline)
                        .foregroundStyle(palette.secondary)
                    HStack(spacing: 8) {
                        StatusDot(tone: tile.tone)
                        Text(tile.figure)
                            .font(.system(.title, design: .rounded).bold())
                            .foregroundStyle(palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(tile.line)
                        .font(.body)
                        .foregroundStyle(palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Backups, \(tile.figure). \(tile.line)")
    }
}
