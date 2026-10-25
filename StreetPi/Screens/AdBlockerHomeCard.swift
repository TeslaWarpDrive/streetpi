import StreetPiCore
import SwiftUI

/// Lavender ad-blocker tile. Tap opens the detail. Hold asks for the existing pause.
struct AdBlockerHomeCard: View {
    var reading: HomeAdBlockerReading
    var onOpen: () -> Void
    var onHold: () -> Void

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showsExplainer = false
    @State private var suppressTap = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: open) {
                card
            }
            .buttonStyle(.plain)
            .simultaneousGesture(hold)
            .accessibilityAction(named: Text("Pause ad blocker"), action: onHold)
            .accessibilityAction(named: Text("What the percent means")) {
                showsExplainer = true
            }
            IconChromeButton(
                title: "What the percent means",
                systemImage: "info.circle",
                action: { showsExplainer = true }
            )
            .padding(8)
        }
        .sheet(isPresented: $showsExplainer) {
            AdBlockerExplainer(reading: reading)
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: AfterglowShape.line) {
            HStack(alignment: .center, spacing: AfterglowShape.line) {
                RingArc(
                    fraction: reading.ringFraction,
                    diameter: dynamicTypeSize.isAccessibilitySize ? 96 : 72
                )
                stateMark
                Spacer(minLength: 36)
            }
            Text("Ad blocker · last 24 hours")
                .font(.subheadline)
                .foregroundStyle(palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(reading.percentText)
                .font(.largeTitle.bold())
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(reading.fractionLine)
                .font(.body)
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AfterglowShape.tilePadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(lavender, in: RoundedRectangle(cornerRadius: AfterglowShape.panel, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AfterglowShape.panel, style: .continuous)
                .strokeBorder(palette.accent.opacity(0.55), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(reading.spoken)
        .accessibilityHint("Opens the ad blocker. Hold to pause it.")
    }

    private var lavender: Color {
        palette.accent.opacity(0.22)
    }

    private var stateMark: some View {
        Text(reading.stateWord)
            .font(.headline.bold())
            .foregroundStyle(stateColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(stateColor.opacity(0.16), in: Capsule())
            .accessibilityHidden(true)
    }

    private var stateColor: Color {
        if reading.isOn {
            return palette.calm
        }
        if reading.stateWord == "OFF" {
            return palette.attention
        }
        return palette.secondary
    }

    private var hold: some Gesture {
        LongPressGesture(minimumDuration: 0.45).onEnded { _ in
            suppressTap = true
            onHold()
        }
    }

    private func open() {
        if suppressTap {
            suppressTap = false
            return
        }
        onOpen()
    }
}
