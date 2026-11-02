import StreetPiCore
import SwiftUI

extension EnvironmentValues {
    /// Set on the tabs that name a rejected away key, so the bar can say it in its one card.
    @Entry var awayKeyNotice: String? = nil
    /// The page says it instead, so the bar stays out of the way of the fields that fix it.
    @Entry var awayKeyOnPage = false
}

/// The small line above every tab while the Pi is out of reach. It counts up on its own.
/// Snapshots draw the frozen clock they were given.
struct AwayBadgeBar: View {
    var status: AwayStatus
    var now: Date
    var onSetUp: () -> Void

    @Environment(\.streetPiStill) private var still
    @Environment(\.awayKeyNotice) private var keyNotice
    @Environment(\.awayKeyOnPage) private var keyOnPage

    var body: some View {
        if keyOnPage {
            EmptyView()
        } else if still {
            AwayBadgeLine(badge: badge(at: now), onSetUp: onSetUp)
        } else {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                AwayBadgeLine(badge: badge(at: context.date), onSetUp: onSetUp)
            }
        }
    }

    private func badge(at date: Date) -> AwayBadge {
        status.badge(now: date).carrying(keyNotice: keyNotice, status: status)
    }
}

extension AwayBadge {
    /// One card while the key is rejected. A mailbox report keeps its age. "Can't reach the Pi" adds nothing.
    func carrying(keyNotice: String?, status: AwayStatus) -> AwayBadge {
        guard let keyNotice else { return self }
        var next = self
        if status.isAway {
            next.detail = [detail, keyNotice].compactMap { $0 }.joined(separator: " ")
            next.spoken = "\(spoken) \(keyNotice)"
        } else {
            next.line = keyNotice
            next.detail = nil
            next.symbol = "key.slash"
            next.spoken = keyNotice
            next.offersSetup = false
        }
        return next
    }
}

private struct AwayBadgeLine: View {
    var badge: AwayBadge
    var onSetUp: () -> Void

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// A step smaller at accessibility sizes, like the status pill, so the page keeps the screen.
    private var lineFont: Font {
        dynamicTypeSize.isAccessibilitySize ? .caption : .footnote
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AfterglowShape.tight) {
            summary
            if badge.offersSetup {
                Button("Open Settings", action: onSetUp)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.accent)
                    .frame(minHeight: 44, alignment: .leading)
            }
        }
        .padding(.horizontal, AfterglowShape.line)
        .padding(.vertical, AfterglowShape.tight)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(AwayBadgeGlass(tone: palette.tone(badge.tone)))
        .padding(.horizontal, AfterglowShape.line)
        .padding(.top, AfterglowShape.tight)
    }

    private var summary: some View {
        HStack(alignment: .firstTextBaseline, spacing: AfterglowShape.tight) {
            Image(systemName: badge.symbol)
                .font(lineFont.weight(.semibold))
                .foregroundStyle(palette.tone(badge.tone))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(badge.line)
                    .font(lineFont.weight(.semibold).monospacedDigit())
                    .foregroundStyle(palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = badge.detail {
                    Text(detail)
                        .font(lineFont)
                        .foregroundStyle(palette.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(badge.spoken)
    }
}

/// Chrome, so it may be glass. A tone tint carries the state. Older iOS gets a material.
private struct AwayBadgeGlass: ViewModifier {
    var tone: Color

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: AfterglowShape.tile, style: .continuous)
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular.tint(tone.opacity(0.14)), in: shape)
                .overlay { shape.strokeBorder(tone.opacity(0.45), lineWidth: 1) }
        } else {
            content
                .background(.ultraThinMaterial, in: shape)
                .overlay { shape.strokeBorder(tone.opacity(0.45), lineWidth: 1) }
        }
    }
}
