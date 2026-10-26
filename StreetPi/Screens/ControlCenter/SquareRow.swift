import StreetPiCore
import SwiftUI

/// Streaming, Remote, DNS, and Address.
/// Four equal squares when each name fits on one line, then two rows, then one column.
struct SquareRow: View {
    var squares: [ServiceSquare]
    var onOpen: (HouseGroup) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            EqualSquareRow(spacing: gap) {
                tiles(squares, fillsHeight: true)
            }
            VStack(alignment: .leading, spacing: gap) {
                HStack(alignment: .top, spacing: gap) {
                    tiles(Array(squares.prefix(2)), fillsHeight: false)
                }
                HStack(alignment: .top, spacing: gap) {
                    tiles(Array(squares.dropFirst(2)), fillsHeight: false)
                }
            }
            VStack(alignment: .leading, spacing: gap) {
                tiles(squares, fillsHeight: false)
            }
        }
    }

    private let gap: CGFloat = 6

    private func tiles(_ squares: [ServiceSquare], fillsHeight: Bool) -> some View {
        ForEach(squares) { square in
            ServiceSquareTile(square: square, fillsHeight: fillsHeight) {
                onOpen(square.group)
            }
        }
    }
}

/// Equal columns. Reports a wider size when a name would have to wrap, so the next row can take over.
private struct EqualSquareRow: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.isEmpty == false else { return .zero }
        let ideals = subviews.map { $0.sizeThatFits(.unspecified) }
        let widest = ideals.map(\.width).max() ?? 0
        let count = CGFloat(subviews.count)
        let gaps = spacing * max(0, count - 1)
        if let width = proposal.width, width.isFinite {
            let share = (width - gaps) / count
            if widest > share + 0.5 {
                let height = ideals.map(\.height).max() ?? 0
                return CGSize(width: widest * count + gaps, height: height)
            }
            let fitted = subviews.map {
                $0.sizeThatFits(ProposedViewSize(width: share, height: share))
            }
            let content = fitted.map(\.height).max() ?? 0
            return CGSize(width: width, height: max(content, share))
        }
        let side = max(widest, ideals.map(\.height).max() ?? 0)
        return CGSize(width: side * count + gaps, height: side)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.isEmpty == false else { return }
        let count = CGFloat(subviews.count)
        let gaps = spacing * max(0, count - 1)
        let share = max(0, (bounds.width - gaps) / count)
        var origin = bounds.minX
        for subview in subviews {
            subview.place(
                at: CGPoint(x: origin, y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: share, height: bounds.height)
            )
            origin += share + spacing
        }
    }
}
