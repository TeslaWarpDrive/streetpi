import StreetPiCore
import SwiftUI
import UIKit

/// One service at a glance. The word sits with the dot.
struct ServiceSquareTile: View {
    var square: ServiceSquare
    var compresses: Bool = false
    var onOpen: () -> Void

    @Environment(\.afterglowPalette) private var palette
    @Environment(\.pinsStreamingTitle) private var pinsStreamingTitle

    var body: some View {
        Button(action: onOpen) {
            VStack(spacing: AfterglowShape.tight) {
                StatusDot(tone: square.tone)
                Text(square.word)
                    .font(.headline)
                    .foregroundStyle(palette.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                UnbrokenTitle(text: square.title, color: palette.secondary)
                    .fixedSize(horizontal: compresses == false, vertical: true)
            }
            .padding(AfterglowShape.line)
            .frame(maxWidth: compresses ? .infinity : nil, minHeight: 96)
            .fixedSize(horizontal: compresses == false, vertical: false)
            .background(palette.panel, in: RoundedRectangle(cornerRadius: AfterglowShape.tile, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AfterglowShape.tile, style: .continuous)
                    .strokeBorder(palette.hairline, lineWidth: 1)
            }
            .background(alignment: .bottom) {
                if square.id == "streaming", pinsStreamingTitle {
                    PinStreamingTitle()
                        .frame(width: 1, height: 1)
                        .accessibilityHidden(true)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(square.title), \(square.word)")
    }
}

private struct PinsStreamingTitleKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// Scrolls the Streaming tile fully into view. Proof snapshots set this.
    var pinsStreamingTitle: Bool {
        get { self[PinsStreamingTitleKey.self] }
        set { self[PinsStreamingTitleKey.self] = newValue }
    }
}

/// A title that stays whole. Narrow columns wrap on character boundaries, never with a hyphen.
struct UnbrokenTitle: UIViewRepresentable {
    var text: String
    var color: Color

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = .center
        label.lineBreakMode = .byCharWrapping
        label.adjustsFontSizeToFitWidth = false
        label.adjustsFontForContentSizeCategory = true
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.accessibilityIdentifier = "service-title"
        apply(label)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        apply(label)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        apply(uiView)
        let font = uiView.font ?? UIFont.preferredFont(forTextStyle: .subheadline)
        let full = (text as NSString).size(withAttributes: [.font: font])
        let limit = proposal.width ?? .greatestFiniteMagnitude
        if limit >= full.width - 0.5 {
            return CGSize(width: ceil(full.width), height: ceil(max(full.height, font.lineHeight)))
        }
        let fitted = uiView.sizeThatFits(CGSize(width: limit, height: .greatestFiniteMagnitude))
        return CGSize(width: ceil(limit), height: ceil(max(fitted.height, font.lineHeight)))
    }

    private func apply(_ label: UILabel) {
        let font = UIFont.preferredFont(forTextStyle: .subheadline, compatibleWith: label.traitCollection)
        let paragraph = NSMutableParagraphStyle()
        paragraph.hyphenationFactor = 0
        paragraph.lineBreakMode = .byCharWrapping
        paragraph.alignment = .center
        label.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: UIColor(color),
                .paragraphStyle: paragraph,
            ]
        )
        label.accessibilityLabel = text
    }
}

/// Pulls the Streaming tile up until it sits fully above the tab bar.
private struct PinStreamingTitle: UIViewRepresentable {
    func makeUIView(context: Context) -> PinStreamingView {
        PinStreamingView()
    }

    func updateUIView(_ view: PinStreamingView, context: Context) {
        view.pin()
    }
}

private final class PinStreamingView: UIView {
    override func didMoveToWindow() {
        super.didMoveToWindow()
        pin()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        pin()
    }

    func pin() {
        guard window != nil, let scroll = enclosingScroll() else { return }
        let frame = convert(bounds, to: scroll)
        guard frame.maxY > 1, scroll.contentSize.height > scroll.bounds.height else { return }
        let visible = scroll.bounds.height - scroll.adjustedContentInset.bottom
        guard visible > 1 else { return }
        let maxOffset = max(0, scroll.contentSize.height - visible)
        let target = min(max(0, frame.maxY - visible + 8), maxOffset)
        guard abs(scroll.contentOffset.y - target) > 1 else { return }
        scroll.setContentOffset(CGPoint(x: 0, y: target), animated: false)
    }

    private func enclosingScroll() -> UIScrollView? {
        var view = superview
        while let current = view {
            if let scroll = current as? UIScrollView, scroll.bounds.height > 80 {
                return scroll
            }
            view = current.superview
        }
        return nil
    }
}
