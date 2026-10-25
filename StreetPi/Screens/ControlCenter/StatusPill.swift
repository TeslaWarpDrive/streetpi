import SwiftUI

/// Overall status. The accent word stays inside the pill, clear of the checked line.
struct StatusPill: View {
    var title: String
    var accentWord: String
    var checkedLine: String

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: AfterglowShape.line) {
                pill(wraps: false)
                checked(wraps: false)
            }
            VStack(alignment: .leading, spacing: AfterglowShape.line) {
                pill(wraps: true)
                checked(wraps: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func pill(wraps: Bool) -> some View {
        words(wraps: wraps)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(palette.panelRaised, in: Capsule())
            .overlay {
                Capsule().strokeBorder(palette.hairlineInteractive, lineWidth: 1)
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
                style: dynamicTypeSize.isAccessibilitySize ? .title3 : .subheadline,
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
