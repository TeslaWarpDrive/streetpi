import StreetPiCore
import SwiftUI

/// Headline on an opaque plate, with an uncovered Aurora band above it.
/// The band stays visible on a narrow phone, where a full-bleed plate used to hide the glow.
struct StatusHeadline: View {
    var title: String
    var accentWord: String
    var tone: PlainEnglishStatus.Tone

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            AuraView(tone: tone)
            HeadlineWords(title: title, accentWord: accentWord)
                .padding(.horizontal, AfterglowShape.block)
                .padding(.vertical, AfterglowShape.line)
                .background(palette.panelRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, AfterglowShape.line)
                .padding(.top, glowBand)
                .padding(.bottom, AfterglowShape.line)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// Large type keeps a shorter band so the words stay on screen. The band never covers the text.
    private var glowBand: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 8 : 72
    }
}
