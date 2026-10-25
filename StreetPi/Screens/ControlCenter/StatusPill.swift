import SwiftUI

/// Overall status on one line. The accent word stays inside the pill.
struct StatusPill: View {
    var title: String
    var accentWord: String
    var checkedLine: String

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: AfterglowShape.tight) {
                pill
                    .fixedSize(horizontal: true, vertical: true)
                checked
                    .fixedSize(horizontal: true, vertical: true)
            }
            VStack(alignment: .leading, spacing: AfterglowShape.tight) {
                pill
                checked
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var pill: some View {
        words
            .font(dynamicTypeSize.isAccessibilitySize ? .title3.bold() : .subheadline.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(palette.panelRaised, in: Capsule())
            .overlay {
                Capsule().strokeBorder(palette.hairlineInteractive, lineWidth: 1)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(title)
    }

    private var checked: some View {
        Text(checkedLine)
            .font(dynamicTypeSize.isAccessibilitySize ? .subheadline : .caption)
            .foregroundStyle(palette.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var words: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 2) {
                ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                    styled(token)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } else {
            HStack(spacing: 4) {
                ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                    styled(token)
                }
            }
            .fixedSize(horizontal: true, vertical: true)
        }
    }

    private var tokens: [String] {
        title.split(separator: " ").map(String.init)
    }

    @ViewBuilder
    private func styled(_ token: String) -> some View {
        if isAccent(token) {
            SheenWord(text: token, minimumScale: 1)
        } else {
            Text(token)
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: true, vertical: true)
                .accessibilityHidden(true)
        }
    }

    private func isAccent(_ token: String) -> Bool {
        guard accentWord.isEmpty == false else { return false }
        let stripped = token.trimmingCharacters(in: .punctuationCharacters)
        return stripped.caseInsensitiveCompare(accentWord) == .orderedSame
    }
}
