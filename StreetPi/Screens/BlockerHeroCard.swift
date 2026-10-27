import StreetPiCore
import SwiftUI

/// The lavender hero: ring, state, the big percent, and its sentence. Tap explains the percent.
struct BlockerHeroCard: View {
    var share: LookupShare
    var enabled: Bool
    var blockingLine: String
    var onExplain: () -> Void

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .largeTitle) private var ringSide: CGFloat = 76

    var body: some View {
        Button(action: onExplain) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: AfterglowShape.line) {
                        ring
                        words
                    }
                } else {
                    HStack(alignment: .center, spacing: AfterglowShape.block) {
                        ring
                        words
                    }
                }
            }
            .padding(AfterglowShape.page)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                enabled ? palette.accent : palette.attention,
                in: RoundedRectangle(cornerRadius: AfterglowShape.panel, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(stateLine). \(share.percentText). \(share.fractionLine)")
        .accessibilityHint("Explains this percent.")
    }

    private var ring: some View {
        ShieldRing(fraction: Double(share.percent) / 100)
            .frame(width: ringSide, height: ringSide)
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: AfterglowShape.tight) {
                Image(systemName: enabled ? "checkmark.circle.fill" : "pause.circle.fill")
                    .font(.subheadline)
                    .accessibilityHidden(true)
                Text(stateLine)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(palette.ground.opacity(0.8))
            Text(share.percentText)
                .font(.system(.largeTitle, design: .rounded).bold().monospacedDigit())
                .foregroundStyle(palette.ground)
                .fixedSize(horizontal: false, vertical: true)
            Text("of lookups were ads or trackers in the last 24 hours")
                .font(.subheadline)
                .foregroundStyle(palette.ground.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var stateLine: String {
        enabled ? "Blocking is on" : blockingLine
    }
}
