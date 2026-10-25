import SwiftUI

/// Overall status. The accent word keeps the Aurora sheen. The checked line sits under it.
struct StatusPill: View {
    var title: String
    var accentWord: String
    var checkedLine: String

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: AfterglowShape.tight) {
            pill
            Text(checkedLine)
                .font(.subheadline)
                .foregroundStyle(palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var pill: some View {
        WordFlow(spacing: dynamicTypeSize.isAccessibilitySize ? 6 : 8) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                styled(token)
            }
        }
        .font(dynamicTypeSize.isAccessibilitySize ? .title.bold() : .title2.bold())
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(minHeight: 44, alignment: .leading)
        .background(palette.panelRaised, in: Capsule())
        .overlay {
            Capsule().strokeBorder(palette.hairlineInteractive, lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
    }

    private var tokens: [String] {
        title.split(separator: " ").map(String.init)
    }

    @ViewBuilder
    private func styled(_ token: String) -> some View {
        if isAccent(token) {
            SheenWord(text: token)
        } else {
            Text(token)
                .foregroundStyle(palette.ink)
                .accessibilityHidden(true)
        }
    }

    private func isAccent(_ token: String) -> Bool {
        guard accentWord.isEmpty == false else { return false }
        let stripped = token.trimmingCharacters(in: .punctuationCharacters)
        return stripped.caseInsensitiveCompare(accentWord) == .orderedSame
    }
}
