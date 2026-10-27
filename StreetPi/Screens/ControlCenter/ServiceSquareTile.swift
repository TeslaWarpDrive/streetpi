import StreetPiCore
import SwiftUI
import UIKit

/// One service at a glance. The icon and dot sit on top. The name and status sit on the bottom.
struct ServiceSquareTile: View {
    var square: ServiceSquare
    /// Default-size tiles share one row and read as squares.
    var readsAsSquare: Bool = false
    var onOpen: () -> Void

    @Environment(\.afterglowPalette) private var palette
    /// About as tall as a phone tile is wide, so the row reads as squares. It grows with the text.
    @ScaledMetric(relativeTo: .caption) private var squareSide: CGFloat = 78

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .center, spacing: 4) {
                    Image(systemName: symbol)
                        .font(.body)
                        .foregroundStyle(palette.accent)
                        .accessibilityHidden(true)
                    Spacer(minLength: 2)
                    StatusDot(tone: square.tone)
                }
                Spacer(minLength: AfterglowShape.line)
                UnbrokenTitle(
                    text: square.title,
                    color: palette.ink,
                    alignment: .left,
                    bold: true,
                    style: .caption1
                )
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                Text(square.word)
                    .font(.caption)
                    .foregroundStyle(palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, AfterglowShape.line)
            .frame(maxWidth: .infinity, minHeight: readsAsSquare ? squareSide : nil, alignment: .top)
            .background(palette.panel, in: RoundedRectangle(cornerRadius: AfterglowShape.tile, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AfterglowShape.tile, style: .continuous)
                    .strokeBorder(palette.hairline, lineWidth: 1)
            }
            .background(alignment: .topLeading) {
                SpokenMark(text: square.word)
                    .frame(width: 1, height: 1)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(square.title), \(square.word)")
    }

    private var symbol: String {
        switch square.group {
        case .streaming:
            "play.tv"
        case .remoteHelp:
            "display.and.arrow.down"
        case .adBlockerAndDNS:
            "shield.lefthalf.filled"
        case .internet:
            "globe"
        case .address:
            "network"
        case .piHealth:
            "cpu"
        case .backups:
            "externaldrive.badge.timemachine"
        case .monitors:
            "list.bullet.rectangle"
        case .smartHome:
            "homekit"
        }
    }
}

/// A title that stays whole. Narrow columns wrap on character boundaries, never with a hyphen.
struct UnbrokenTitle: UIViewRepresentable {
    var text: String
    var color: Color
    var alignment: NSTextAlignment = .center
    var bold: Bool = false
    var style: UIFont.TextStyle = .subheadline

    fileprivate func makeUIView(context: Context) -> WholeTitleLabel {
        let label = WholeTitleLabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byCharWrapping
        label.adjustsFontSizeToFitWidth = false
        label.adjustsFontForContentSizeCategory = false
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.accessibilityIdentifier = "service-title"
        configure(label)
        return label
    }

    fileprivate func updateUIView(_ label: WholeTitleLabel, context: Context) {
        configure(label)
    }

    private func configure(_ label: WholeTitleLabel) {
        label.source = text
        label.ink = UIColor(color)
        label.bold = bold
        label.textStyle = style
        label.textAlign = alignment
        label.fit()
    }

    fileprivate func sizeThatFits(_ proposal: ProposedViewSize, uiView: WholeTitleLabel, context: Context) -> CGSize? {
        configure(uiView)
        let font = Self.font(
            text: text,
            bold: bold,
            style: style,
            fitting: proposal.width ?? .greatestFiniteMagnitude,
            traits: uiView.traitCollection
        )
        let full = (text as NSString).size(withAttributes: [.font: font])
        let limit = proposal.width ?? full.width
        if limit >= full.width - 0.5 {
            return CGSize(width: ceil(full.width), height: ceil(max(full.height, font.lineHeight)))
        }
        let fitted = (text as NSString).boundingRect(
            with: CGSize(width: limit, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        ).size
        return CGSize(width: ceil(limit), height: ceil(max(fitted.height, font.lineHeight)))
    }

    /// One line at the text style when it fits. A narrow default-size tile scales the
    /// weight down just enough to keep the whole word, instead of wrapping "Streaming".
    /// Accessibility sizes keep the full text style and wrap.
    fileprivate static func font(
        text: String,
        bold: Bool,
        style: UIFont.TextStyle,
        fitting width: CGFloat,
        traits: UITraitCollection
    ) -> UIFont {
        let base = UIFont.preferredFont(forTextStyle: style, compatibleWith: traits)
        let weight: UIFont.Weight = bold ? .bold : .regular
        let preferred = UIFont.systemFont(ofSize: base.pointSize, weight: weight)
        guard width.isFinite, width > 1 else { return preferred }
        let full = (text as NSString).size(withAttributes: [.font: preferred]).width
        guard full > width, traits.preferredContentSizeCategory.isAccessibilityCategory == false else {
            return preferred
        }
        let scaled = max(base.pointSize * 0.7, base.pointSize * (width - 1) / full)
        return UIFont.systemFont(ofSize: scaled, weight: weight)
    }
}

/// Draws a tile name on one line at the default text size, and wraps at accessibility sizes.
private final class WholeTitleLabel: UILabel {
    var source = ""
    var ink = UIColor.label
    var bold = false
    var textStyle: UIFont.TextStyle = .caption1
    var textAlign: NSTextAlignment = .left
    private var stamp = ""

    override func layoutSubviews() {
        super.layoutSubviews()
        fit()
    }

    func fit() {
        let width = bounds.width > 1 ? bounds.width : .greatestFiniteMagnitude
        let font = UnbrokenTitle.font(
            text: source,
            bold: bold,
            style: textStyle,
            fitting: width,
            traits: traitCollection
        )
        let next = "\(source)|\(ink)|\(bold)|\(textStyle.rawValue)|\(width)|\(font.pointSize)"
        if stamp == next { return }
        stamp = next
        textAlignment = textAlign
        let paragraph = NSMutableParagraphStyle()
        paragraph.hyphenationFactor = 0
        paragraph.lineBreakMode = .byCharWrapping
        paragraph.alignment = textAlign
        attributedText = NSAttributedString(
            string: source,
            attributes: [
                .font: font,
                .foregroundColor: ink,
                .paragraphStyle: paragraph,
            ]
        )
        accessibilityLabel = source
    }
}
