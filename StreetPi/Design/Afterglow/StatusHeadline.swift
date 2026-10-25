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
        HeadlineWords(title: title, accentWord: accentWord)
            .padding(.horizontal, AfterglowShape.block)
            .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? AfterglowShape.tight : AfterglowShape.line)
            .background(palette.panelRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, AfterglowShape.line)
            .padding(.top, glowBand)
            .padding(.bottom, AfterglowShape.line)
            .background(alignment: .top) {
                AuraView(tone: tone)
                    .frame(height: glowBand + 24)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
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
