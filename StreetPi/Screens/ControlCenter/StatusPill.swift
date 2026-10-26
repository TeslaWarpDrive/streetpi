import SwiftUI

/// Overall status. The accent word stays inside the pill, clear of the checked line.
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
                    pill(wraps: true)
                    checked(wraps: true)
                }
            } else {
                Apart(gap: AfterglowShape.line) {
                    pill(wraps: false)
                    checked(wraps: false)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pill(wraps: Bool) -> some View {
        words(wraps: wraps)
            .padding(.horizontal, 10)
            .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? 2 : 4)
            .background(palette.panelRaised, in: Capsule())
            .overlay {
                Capsule().strokeBorder(palette.hairlineInteractive, lineWidth: 1)
            }
            .clipShape(Capsule())
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

    @ViewBuilder
    private func words(wraps: Bool) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                    styled(token, wraps: wraps)
                }
            }
        } else {
            HStack(spacing: 4) {
                ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                    styled(token, wraps: false)
                }
            }
            .fixedSize(horizontal: wraps == false, vertical: true)
        }
    }

    private var tokens: [String] {
        title.split(separator: " ").map(String.init)
    }

    @ViewBuilder
    private func styled(_ token: String, wraps: Bool) -> some View {
        if isAccent(token) {
            SheenWord(text: token, minimumScale: 1)
                .background {
                    ScrollAnchor(name: "status-accent")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityHidden(true)
                }
                .fixedSize(horizontal: true, vertical: true)
        } else {
            FittingText(
                text: token,
                color: palette.ink,
                style: .subheadline,
                weight: .bold,
                identifier: "status-word",
                breaksWords: true
            )
            .fixedSize(horizontal: wraps == false, vertical: true)
            .frame(maxWidth: wraps ? .infinity : nil, alignment: .leading)
        }
    }

    private func isAccent(_ token: String) -> Bool {
        guard accentWord.isEmpty == false else { return false }
        let stripped = token.trimmingCharacters(in: .punctuationCharacters)
        return stripped.caseInsensitiveCompare(accentWord) == .orderedSame
    }
}

/// Puts the checked line beside the pill when both fit, and under it when they do not.
/// The two frames stay a gap apart either way, so the accent cannot cover the checked line.
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
            let pillSize = ProposedViewSize(width: pill.width, height: pill.height)
            let checkedSize = ProposedViewSize(width: checked.width, height: checked.height)
            subviews[0].place(
                at: CGPoint(x: bounds.minX, y: bounds.midY),
                anchor: .leading,
                proposal: pillSize
            )
            subviews[1].place(
                at: CGPoint(x: bounds.minX + pill.width + gap, y: bounds.midY),
                anchor: .leading,
                proposal: checkedSize
            )
        } else {
            let stackedPill = subviews[0].sizeThatFits(ProposedViewSize(width: bounds.width, height: nil))
            subviews[0].place(
                at: CGPoint(x: bounds.minX, y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: bounds.width, height: stackedPill.height)
            )
            subviews[1].place(
                at: CGPoint(x: bounds.minX, y: bounds.minY + stackedPill.height + gap),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: bounds.width, height: nil)
            )
        }
    }
}
