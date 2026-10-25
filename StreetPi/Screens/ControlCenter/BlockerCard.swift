import StreetPiCore
import SwiftUI

/// Lavender ad-blocker tile.
/// Tap opens the detail. Hold starts the pause confirmation.
/// The info button explains the percent.
struct BlockerCard: View {
    var tile: BlockerTile
    var onOpen: () -> Void
    var onHold: () -> Void
    var onInfo: () -> Void

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        BoardPanel(lavender: true) {
            openControl
                .overlay(alignment: .topTrailing) {
                    infoButton
                }
        }
    }

    private var openControl: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 4) {
                    ring
                    stateLabel
                    Spacer(minLength: 32)
                }
                .frame(minHeight: 32)
                Text("Ad blocker · last 24 hours")
                    .font(.caption)
                    .foregroundStyle(palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                percentRow
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(LongPressGesture(minimumDuration: 0.5).onEnded { _ in
            onHold()
        })
        .accessibilityLabel(spoken)
        .accessibilityHint(tile.canPause ? "Opens the ad blocker. Hold to pause it." : "Opens the ad blocker.")
        .modifier(PauseBlockerAction(enabled: tile.canPause, action: onHold))
    }

    private var percentRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                percent
                Text(plainLine)
                    .font(.caption)
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: true, vertical: true)
            }
            VStack(alignment: .leading, spacing: 2) {
                percent
                Text(plainLine)
                    .font(.caption)
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var percent: some View {
        Text(tile.percentText)
            .font(.system(dynamicTypeSize.isAccessibilitySize ? .title : .title2, design: .rounded).bold())
            .foregroundStyle(palette.ink)
            .fixedSize(horizontal: false, vertical: true)
            .background(alignment: .topLeading) {
                ScrollAnchor(name: "blocker-fraction")
                    .frame(width: 1, height: 1)
                    .accessibilityHidden(true)
            }
    }

    /// The spoken line stays whole. The tile keeps the short "About 1 in 5" clause.
    private var plainLine: String {
        let line = tile.fractionLine
        guard let mark = line.range(of: " things") else { return line }
        return String(line[..<mark.lowerBound])
    }

    private var ring: some View {
        RingArc(fraction: tile.fraction)
            .frame(width: 24, height: 24)
    }

    private var stateLabel: some View {
        HStack(spacing: 4) {
            StatusDot(tone: tile.canPause ? .calm : .attention)
            Text(tile.stateWord)
                .font(.subheadline.bold())
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityHidden(true)
    }

    private var infoButton: some View {
        Button("About this percent", systemImage: "info.circle", action: onInfo)
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .font(.body)
            .foregroundStyle(palette.accent)
            .frame(width: 32, height: 32)
    }

    private var spoken: String {
        "Ad blocker, \(tile.stateWord), \(tile.percentText). \(tile.fractionLine)"
    }
}
