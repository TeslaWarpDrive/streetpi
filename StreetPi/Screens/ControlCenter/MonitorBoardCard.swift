import StreetPiCore
import SwiftUI

/// Monitors: the title and the count on one line, then a strip of rounded squares.
struct MonitorBoardCard: View {
    var tile: MonitorTile

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        BoardPanel {
            VStack(alignment: .leading, spacing: AfterglowShape.line) {
                heading
                Spacer(minLength: 0)
                SquareStrip(gap: 3) {
                    ForEach(tile.marks) { mark in
                        MonitorSquare(up: mark.up)
                    }
                }
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

    @ViewBuilder
    private var heading: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 2) {
                title
                count
            }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline, spacing: AfterglowShape.tight) {
                    title
                    Spacer(minLength: AfterglowShape.tight)
                    count
                }
                VStack(alignment: .leading, spacing: 2) {
                    title
                    count
                }
            }
        }
    }

    private var title: some View {
        Text("Monitors")
            .font(.subheadline.bold())
            .foregroundStyle(palette.ink)
            .fixedSize(horizontal: dynamicTypeSize.isAccessibilitySize == false, vertical: true)
    }

    private var count: some View {
        Text(countLine)
            .font(.subheadline.monospaced())
            .foregroundStyle(palette.ink)
            .fixedSize(horizontal: false, vertical: true)
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

/// Equal squares that share the width. A long list wraps onto more rows instead of shrinking away.
struct SquareStrip: Layout {
    var gap: CGFloat
    var smallest: CGFloat = 9
    var largest: CGFloat = 16

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? CGFloat(subviews.count) * (largest + gap)
        let grid = grid(count: subviews.count, width: width)
        let height = CGFloat(grid.rows) * grid.side + CGFloat(max(grid.rows - 1, 0)) * gap
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let grid = grid(count: subviews.count, width: bounds.width)
        for (index, subview) in subviews.enumerated() {
            let row = index / grid.perRow
            let column = index % grid.perRow
            let point = CGPoint(
                x: bounds.minX + CGFloat(column) * (grid.side + grid.spacing),
                y: bounds.minY + CGFloat(row) * (grid.side + gap)
            )
            subview.place(
                at: point,
                anchor: .topLeading,
                proposal: ProposedViewSize(width: grid.side, height: grid.side)
            )
        }
    }

    /// One row when the squares fit at a readable size; otherwise as many rows as it takes.
    private struct GridMetrics {
        var side: CGFloat
        var perRow: Int
        var rows: Int
        var spacing: CGFloat
    }

    private func grid(count: Int, width: CGFloat) -> GridMetrics {
        guard count > 0, width > 0 else { return GridMetrics(side: 0, perRow: 1, rows: 0, spacing: gap) }
        let oneRow = (width - CGFloat(count - 1) * gap) / CGFloat(count)
        if oneRow >= smallest {
            let side = min(oneRow, largest)
            let spacing = count > 1 ? (width - side * CGFloat(count)) / CGFloat(count - 1) : 0
            return GridMetrics(side: side, perRow: count, rows: 1, spacing: oneRow > largest ? spacing : gap)
        }
        let perRow = max(1, Int((width + gap) / (smallest + gap)))
        let side = (width - CGFloat(perRow - 1) * gap) / CGFloat(perRow)
        let rows = (count + perRow - 1) / perRow
        return GridMetrics(side: side, perRow: perRow, rows: rows, spacing: gap)
    }
}
