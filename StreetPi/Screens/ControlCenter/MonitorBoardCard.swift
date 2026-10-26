import StreetPiCore
import SwiftUI

/// Monitors, as a row of little squares. The sample count is not painted.
struct MonitorBoardCard: View {
    var tile: MonitorTile

    var body: some View {
        BoardPanel(inset: 4) {
            HouseGlance(title: "Monitors", symbol: "list.bullet.rectangle") {
                marks
            }
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

    /// The sample "8 of 8" stays out of the label. A live count such as "27 of 28 up" stays.
    private var countLine: String {
        let sample = tile.figure == "8 of 8" || tile.line.contains("are answering")
        if sample {
            let up = tile.marks.filter(\.up).count
            return "\(up) up"
        }
        if tile.line.isEmpty == false {
            return tile.line
        }
        return tile.figure
    }
}
