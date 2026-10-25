import SwiftUI

/// The headline. The accent word carries the Aurora sheen. The rest stays ink.
struct HeadlineWords: View {
    var title: String
    var accentWord: String

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        line
            .font(dynamicTypeSize.isAccessibilitySize ? AfterglowType.title : AfterglowType.display)
            .tracking(dynamicTypeSize.isAccessibilitySize ? 0 : -0.5)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var line: Text {
        guard let range = title.range(of: accentWord), accentWord.isEmpty == false else {
            return Text(title).foregroundStyle(palette.ink)
        }
        var end = range.upperBound
        if end < title.endIndex {
            let mark = title[end]
            if mark == "." || mark == "!" || mark == "?" {
                end = title.index(after: end)
            }
        }
        let prefix = String(title[..<range.lowerBound])
        let word = String(title[range.lowerBound..<end])
        let suffix = String(title[end...])
        return Text(prefix).foregroundStyle(palette.ink)
            + colored(word)
            + Text(suffix).foregroundStyle(palette.ink)
    }

    private func colored(_ word: String) -> Text {
        Text(word).foregroundStyle(sheen)
    }

    private var sheen: LinearGradient {
        LinearGradient(
            colors: [palette.auraBlue, palette.auraViolet, palette.accent],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
