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
            .padding(.horizontal, AfterglowShape.line - 4)
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

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.textAlignment = alignment
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
        let font = uiView.font ?? UIFont.preferredFont(forTextStyle: style)
        let full = (text as NSString).size(withAttributes: [.font: font])
        let limit = proposal.width ?? .greatestFiniteMagnitude
        if limit >= full.width - 0.5 {
            return CGSize(width: ceil(full.width), height: ceil(max(full.height, font.lineHeight)))
        }
        let fitted = uiView.sizeThatFits(CGSize(width: limit, height: .greatestFiniteMagnitude))
        return CGSize(width: ceil(limit), height: ceil(max(fitted.height, font.lineHeight)))
    }

    private func apply(_ label: UILabel) {
        let base = UIFont.preferredFont(forTextStyle: style, compatibleWith: label.traitCollection)
        let font = bold ? UIFont.systemFont(ofSize: base.pointSize, weight: .bold) : base
        label.textAlignment = alignment
        let paragraph = NSMutableParagraphStyle()
        paragraph.hyphenationFactor = 0
        paragraph.lineBreakMode = .byCharWrapping
        paragraph.alignment = alignment
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
