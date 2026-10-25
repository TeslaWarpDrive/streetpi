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
            VStack(alignment: .leading, spacing: AfterglowShape.line) {
                HStack(alignment: .center, spacing: AfterglowShape.line) {
                    ring
                    VStack(alignment: .leading, spacing: AfterglowShape.tight) {
                        HStack(alignment: .center, spacing: AfterglowShape.line) {
                            stateLabel
                            Spacer(minLength: 44)
                        }
                        Text("Ad blocker · last 24 hours")
                            .font(.subheadline)
                            .foregroundStyle(palette.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(tile.percentText)
                            .font(.system(.largeTitle, design: .rounded).bold())
                            .foregroundStyle(palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Text(tile.fractionLine)
                    .font(.body)
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
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

    private var ring: some View {
        RingArc(fraction: tile.fraction)
            .frame(width: AfterglowShape.ring, height: AfterglowShape.ring)
            .scaleEffect(72 / AfterglowShape.ring)
            .frame(width: 72, height: 72)
    }

    private var stateLabel: some View {
        HStack(spacing: 6) {
            StatusDot(tone: tile.canPause ? .calm : .attention)
            Text(tile.stateWord)
                .font(.headline)
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityHidden(true)
    }

    private var infoButton: some View {
        Button("About this percent", systemImage: "info.circle", action: onInfo)
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .font(.title3)
            .foregroundStyle(palette.accent)
            .frame(minWidth: 44, minHeight: 44)
    }

    private var spoken: String {
        "Ad blocker, \(tile.stateWord), \(tile.percentText). \(tile.fractionLine)"
    }
}
