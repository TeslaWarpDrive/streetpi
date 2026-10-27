import SwiftUI

/// Overall status. The green phrase stays inside the pill. “Checked …” sits beside it.
struct StatusPill: View {
    var title: String
    var accentWord: String
    var checkedLine: String

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: AfterglowShape.line) {
                    pill
                    checked(wraps: true)
                }
            } else {
                Apart(gap: AfterglowShape.tight) {
                    pill
                    checked(wraps: false)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var pill: some View {
        HStack(spacing: 6) {
            StatusDot(tone: .calm)
            Text(title)
                .font(.footnote.bold())
                .foregroundStyle(palette.calm)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(palette.calm.opacity(0.16), in: Capsule())
        .overlay {
            Capsule().strokeBorder(palette.calm.opacity(0.45), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }

    private func checked(wraps: Bool) -> some View {
        FittingText(
            text: checkedLine,
            color: palette.secondary,
            style: dynamicTypeSize.isAccessibilitySize ? .subheadline : .caption1,
            weight: .regular,
            identifier: "checked-line",
            breaksWords: false
        )
        .fixedSize(horizontal: wraps == false, vertical: true)
        .frame(maxWidth: wraps ? .infinity : nil, alignment: .leading)
    }
}

/// Puts the checked line beside the pill when both fit, and under it when they do not.
private struct Apart: Layout {
    var gap: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count >= 2 else { return .zero }
        let limit = proposal.width ?? 10_000
        let pill = subviews[0].sizeThatFits(.unspecified)
        let checked = subviews[1].sizeThatFits(.unspecified)
        if pill.width + gap + checked.width <= limit + 0.5 {
            return CGSize(
                width: min(limit, pill.width + gap + checked.width),
                height: max(pill.height, checked.height)
            )
        }
        let stackedPill = subviews[0].sizeThatFits(ProposedViewSize(width: limit, height: nil))
        let stackedChecked = subviews[1].sizeThatFits(ProposedViewSize(width: limit, height: nil))
        return CGSize(width: limit, height: stackedPill.height + gap + stackedChecked.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count >= 2 else { return }
        let pill = subviews[0].sizeThatFits(.unspecified)
        let checked = subviews[1].sizeThatFits(.unspecified)
        let sideBySide = pill.width + gap + checked.width <= bounds.width + 0.5
        if sideBySide {
            subviews[0].place(
                at: CGPoint(x: bounds.minX, y: bounds.midY),
                anchor: .leading,
                proposal: ProposedViewSize(width: pill.width, height: pill.height)
            )
            subviews[1].place(
                at: CGPoint(x: bounds.minX + pill.width + gap, y: bounds.midY),
                anchor: .leading,
                proposal: ProposedViewSize(width: checked.width, height: checked.height)
            )
        } else {
            let stackedPill = subviews[0].sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            subviews[0].place(
                at: CGPoint(x: bounds.minX, y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: bounds.width, height: stackedPill.height)
            )
            let checkedY = bounds.minY + stackedPill.height + gap
            subviews[1].place(
                at: CGPoint(x: bounds.minX, y: checkedY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: bounds.width, height: nil)
            )
        }
    }
}
