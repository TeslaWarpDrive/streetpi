import SwiftUI

/// Lays a column out at the width it was offered.
/// A long word must not widen the scroll view, or the phone clips both edges.
struct FitOfferedWidth: Layout {
    var maxWidth: CGFloat?

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let subview = subviews.first else { return .zero }
        guard let offered = bounded(proposal.width) else {
            return subview.sizeThatFits(proposal)
        }
        let child = subview.sizeThatFits(ProposedViewSize(width: cap(offered), height: nil))
        return CGSize(width: offered, height: child.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let subview = subviews.first else { return }
        let width = cap(bounds.width)
        subview.place(
            at: CGPoint(x: bounds.minX, y: bounds.minY),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: width, height: nil)
        )
    }

    private func bounded(_ width: CGFloat?) -> CGFloat? {
        guard let width, width.isFinite, width > 1 else { return nil }
        return width
    }

    private func cap(_ width: CGFloat) -> CGFloat {
        guard let maxWidth else { return width }
        return min(width, maxWidth)
    }
}
