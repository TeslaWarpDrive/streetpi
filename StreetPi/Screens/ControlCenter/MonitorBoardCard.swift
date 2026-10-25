import StreetPiCore
import SwiftUI

/// N of N up, with one square for each monitor.
struct MonitorBoardCard: View {
    var tile: MonitorTile

    @Environment(\.afterglowPalette) private var palette
    @ScaledMetric(relativeTo: .body) private var markSide: CGFloat = 18

    var body: some View {
        BoardPanel {
            VStack(alignment: .leading, spacing: AfterglowShape.line) {
                Text("Monitors")
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
                marks
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    private var marks: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: markSide), spacing: 6)],
            alignment: .leading,
            spacing: 6
        ) {
            ForEach(tile.marks) { mark in
                MonitorSquare(up: mark.up, side: markSide)
            }
        }
        .accessibilityHidden(true)
    }

    private var spoken: String {
        let names = tile.marks.map { "\($0.name), \($0.word)" }.joined(separator: ". ")
        if names.isEmpty {
            return "Monitors. \(tile.line)"
        }
        return "Monitors, \(tile.figure). \(tile.line) \(names)"
    }
}
