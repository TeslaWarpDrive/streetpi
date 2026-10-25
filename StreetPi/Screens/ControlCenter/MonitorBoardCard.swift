import StreetPiCore
import SwiftUI

/// How the monitors are doing, in one short line. Names stay in the spoken label.
struct MonitorBoardCard: View {
    var tile: MonitorTile

    var body: some View {
        BoardPanel {
            CompactFact(title: "Monitors", value: shortStatus, tone: nil)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    /// Keeps the live count out of the sample figure. "8 of 8" is not painted.
    private var shortStatus: String {
        let line = tile.line
        if line.hasPrefix("All ") && line.contains("are answering") {
            return "All answering"
        }
        if line.contains(" are answering") {
            return line.replacingOccurrences(of: " are answering.", with: "")
        }
        return line
    }

    private var spoken: String {
        let names = tile.marks.map { "\($0.name), \($0.word)" }.joined(separator: ". ")
        if names.isEmpty {
            return "Monitors. \(shortStatus)"
        }
        return "Monitors. \(shortStatus). \(names)"
    }
}
