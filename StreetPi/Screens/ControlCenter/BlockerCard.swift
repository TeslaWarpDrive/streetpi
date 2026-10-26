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
        BoardPanel(lavender: true, inset: 4) {
            openControl
                .overlay(alignment: .topTrailing) {
                    infoButton
                }
        }
    }

    private var openControl: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .center, spacing: 4) {
                    ShieldRing(fraction: tile.fraction)
                        .frame(width: 22, height: 22)
                    Spacer(minLength: 4)
                    stateLabel
                    Color.clear
                        .frame(width: 22, height: 22)
                        .accessibilityHidden(true)
                }
                Text("Ad blocker · last 24 hours")
                    .font(.caption2)
                    .foregroundStyle(onLavender.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
                Text(tile.percentText)
                    .font(.system(dynamicTypeSize.isAccessibilitySize ? .title : .title2, design: .rounded).bold())
                    .foregroundStyle(onLavender)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(alignment: .topLeading) {
                        ScrollAnchor(name: "blocker-fraction")
                            .frame(width: 1, height: 1)
                            .accessibilityHidden(true)
                    }
                FittingText(
                    text: tile.fractionLine,
                    color: onLavender,
                    style: .caption1,
                    weight: .regular,
                    identifier: "blocker-plain",
                    breaksWords: false
                )
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
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

    private var onLavender: Color {
        palette.ground
    }

    private var stateLabel: some View {
        Text(tile.stateWord)
            .font(.subheadline.bold())
            .foregroundStyle(onLavender)
            .fixedSize(horizontal: true, vertical: true)
            .accessibilityHidden(true)
    }

    private var infoButton: some View {
        Button("About this percent", systemImage: "info.circle", action: onInfo)
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .font(.body)
            .foregroundStyle(onLavender)
            .frame(width: 22, height: 22)
    }

    private var spoken: String {
        "Ad blocker, \(tile.stateWord), \(tile.percentText). \(tile.fractionLine)"
    }
}

/// A full ring with a shield in the middle. The arc is the Aurora glow.
private struct ShieldRing: View {
    var fraction: Double

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        ZStack {
            Circle()
                .stroke(palette.ground.opacity(0.28), lineWidth: 3)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(ringGradient, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: "shield.fill")
                .font(.caption2)
                .foregroundStyle(palette.ground)
                .accessibilityHidden(true)
        }
        .accessibilityHidden(true)
    }

    private var clamped: Double {
        min(max(fraction, 0), 1)
    }

    private var ringGradient: LinearGradient {
        LinearGradient(
            colors: [palette.auraTeal, palette.auraBlue, palette.auraViolet],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
