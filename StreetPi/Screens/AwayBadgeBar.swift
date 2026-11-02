import StreetPiCore
import SwiftUI

extension EnvironmentValues {
    /// Set on the tabs that name a rejected away key, so the bar can say it in its one card.
    @Entry var awayKeyNotice: String? = nil
    /// The page says it instead, so the bar leaves it out and keeps only a mailbox report's age.
    @Entry var awayKeyOnPage = false
    /// Already on Settings, so a button that opens it would do nothing.
    @Entry var awayOnSettings = false
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
    @Environment(\.awayOnSettings) private var onSettings

    var body: some View {
        if status.showsBar(keyOnPage: keyOnPage) == false {
            EmptyView()
        } else if still {
            AwayBadgeLine(badge: badge(at: now), capped: capped, onSetUp: onSetUp)
        } else {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                AwayBadgeLine(badge: badge(at: context.date), capped: capped, onSetUp: onSetUp)
            }
        }
    }

    private var capped: Bool {
        status.capsBar(keyNotice: keyNotice, keyOnPage: keyOnPage)
    }

    private func badge(at date: Date) -> AwayBadge {
        status.badge(now: date).carrying(
            keyNotice: keyNotice, status: status, keyOnPage: keyOnPage, onSettings: onSettings
        )
    }
}

extension AwayStatus {
    /// The mailbox's state stays up on every tab, so a report's age does too.
    /// With no mailbox in use the page's message is all there is to say.
    func showsBar(keyOnPage: Bool) -> Bool {
        keyOnPage == false || isAway
    }

    /// The age, a mailbox problem, and the key message can fill a small phone at the largest text.
    func capsBar(keyNotice: String?, keyOnPage: Bool) -> Bool {
        isAway && (keyNotice != nil || keyOnPage)
    }
}

extension AwayBadge {
    /// One card while the key is rejected. A mailbox report keeps its age. "Can't reach the Pi" adds nothing.
    func carrying(
        keyNotice: String?, status: AwayStatus, keyOnPage: Bool = false, onSettings: Bool = false
    ) -> AwayBadge {
        var next = self
        next.offersSetup = offersSetup && onSettings == false
        guard let keyNotice, keyOnPage == false else { return next }
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
    /// The most the card may take. It takes less when the text is short or the screen is.
    private static let heightLimit: CGFloat = 260

    var badge: AwayBadge
    var capped: Bool
    var onSetUp: () -> Void

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// A step smaller at accessibility sizes, like the status pill, so the page keeps the screen.
    private var lineFont: Font {
        dynamicTypeSize.isAccessibilitySize ? .caption : .footnote
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AfterglowShape.tight) {
            fittedSummary
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

    /// Short text keeps its own height. Past the limit the card scrolls, so the page stays reachable.
    @ViewBuilder
    private var fittedSummary: some View {
        if capped {
            CappedHeight(limit: Self.heightLimit) {
                ScrollView {
                    summary.frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollBounceBehavior(.basedOnSize)
                .scrollIndicators(.visible)
                .scrollIndicatorsFlash(onAppear: true)
            }
        } else {
            summary
        }
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

/// A scroll view takes all the height it is offered, so this offers only what its content wants.
private struct CappedHeight: Layout {
    var limit: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let content = subviews.first else { return .zero }
        let natural = content.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil))
        return CGSize(width: natural.width, height: min(natural.height, limit, proposal.height ?? limit))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
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
