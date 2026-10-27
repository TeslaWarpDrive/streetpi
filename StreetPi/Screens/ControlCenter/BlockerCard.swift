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
    @ScaledMetric(relativeTo: .title) private var ringSide: CGFloat = 44
    @ScaledMetric(relativeTo: .body) private var infoSide: CGFloat = 28

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
            VStack(alignment: .leading, spacing: AfterglowShape.tight) {
                HStack(alignment: .center, spacing: 0) {
                    ShieldRing(fraction: tile.fraction)
                        .frame(width: ringSide, height: ringSide)
                    Spacer(minLength: AfterglowShape.tight)
                    stateLabel
                    Color.clear
                        .frame(width: max(infoSide, 44), height: max(infoSide, 44))
                        .accessibilityHidden(true)
                }
                .padding(.bottom, 2)
                windowLabel
                Text(tile.percentText)
                    .font(.system(.largeTitle, design: .rounded).bold().monospacedDigit())
                    .foregroundStyle(onLavender)
                    .fixedSize(horizontal: false, vertical: true)
                FittingText(
                    text: tile.fractionLine,
                    color: onLavender,
                    style: .subheadline,
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

    /// One line when it fits. A narrow card uses the shorter wording before it wraps.
    private var windowLabel: some View {
        ViewThatFits(in: .horizontal) {
            windowText("Ad blocker · last 24 hours")
                .fixedSize(horizontal: true, vertical: true)
            windowText("Ad blocker · 24 hours")
                .fixedSize(horizontal: true, vertical: true)
            windowText("Ad blocker · 24h")
                .fixedSize(horizontal: true, vertical: true)
            windowText("Ad blocker · last 24 hours")
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func windowText(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(onLavender.opacity(0.78))
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
        Button("About this percent", systemImage: "info", action: onInfo)
            .labelStyle(.iconOnly)
            .buttonStyle(.plain)
            .font(.footnote.bold())
            .foregroundStyle(onLavender)
            .frame(width: infoSide, height: infoSide)
            .background(onLavender.opacity(0.12), in: Circle())
            .overlay {
                Circle().strokeBorder(onLavender, lineWidth: 1.5)
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
    }

    private var spoken: String {
        "Ad blocker, \(tile.stateWord), \(tile.percentText). \(tile.fractionLine)"
    }
}

/// A full ring with a shield in the middle. On the lavender card the arc is the ground color, as in the mock.
struct ShieldRing: View {
    var fraction: Double

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        GeometryReader { proxy in
            let line = max(3, proxy.size.width * 0.1)
            ZStack {
                Circle()
                    .stroke(palette.ground.opacity(0.22), lineWidth: line)
                Circle()
                    .trim(from: 0, to: clamped)
                    .stroke(palette.ground, style: StrokeStyle(lineWidth: line, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Image(systemName: "checkmark.shield.fill")
                    .font(.body)
                    .foregroundStyle(palette.ground)
                    .accessibilityHidden(true)
            }
            .padding(line / 2)
        }
        .accessibilityHidden(true)
    }

    private var clamped: Double {
        min(max(fraction, 0), 1)
    }
}
