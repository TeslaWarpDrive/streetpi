import StreetPiCore
import SwiftUI

/// Monitors, as a count and a row of rounded squares.
struct MonitorBoardCard: View {
    var tile: MonitorTile

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        BoardPanel(inset: 4) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 6) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.footnote)
                        .foregroundStyle(palette.accent)
                        .frame(width: 22, height: 22)
                        .background(palette.accent.opacity(0.16), in: Circle())
                        .accessibilityHidden(true)
                    Text("Monitors")
                        .font(.footnote.bold())
                        .foregroundStyle(palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(countLine)
                    .font(.caption2)
                    .foregroundStyle(palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                marks
            }
        }
        .background(alignment: .topLeading) {
            SpokenMark(text: countLine)
                .frame(width: 1, height: 1)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    private var marks: some View {
        HStack(spacing: 3) {
            ForEach(tile.marks) { mark in
                MonitorSquare(up: mark.up, side: 8)
                    .accessibilityLabel("\(mark.name), \(mark.word)")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var spoken: String {
        let names = tile.marks.map { "\($0.name), \($0.word)" }.joined(separator: ". ")
        if names.isEmpty {
            return "Monitors. \(countLine)"
        }
        return "Monitors. \(countLine). \(names)"
    }

    /// Sample and live counts share one shape: "8 of 8 up", "27 of 28 up".
    private var countLine: String {
        let sample = tile.figure == "8 of 8" || tile.line.contains("are answering")
        if sample {
            let up = tile.marks.filter(\.up).count
            return "\(up) of \(tile.marks.count) up"
        }
        if tile.line.isEmpty == false {
            return tile.line
        }
        return tile.figure
    }
}
