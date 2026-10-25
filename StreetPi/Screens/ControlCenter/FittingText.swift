import SwiftUI
import UIKit

/// A line that wraps inside the width it is offered.
/// Hyphenation stays off, so a word never breaks as "Stream-ing."
/// A single word that cannot fit breaks on characters instead of clipping.
struct FittingText: UIViewRepresentable {
    var text: String
    var color: Color
    var style: UIFont.TextStyle
    var weight: UIFont.Weight
    var identifier: String
    var breaksWords: Bool

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.adjustsFontSizeToFitWidth = false
        label.adjustsFontForContentSizeCategory = true
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.required, for: .vertical)
        label.isAccessibilityElement = true
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
        let limit = proposal.width
        guard let limit, limit.isFinite, limit + 0.5 < full.width else {
            return CGSize(width: ceil(full.width), height: ceil(max(full.height, font.lineHeight)))
        }
        let fitted = uiView.sizeThatFits(CGSize(width: limit, height: 10_000))
        return CGSize(width: ceil(limit), height: ceil(max(fitted.height, font.lineHeight)))
    }

    private func apply(_ label: UILabel) {
        let base = UIFont.preferredFont(forTextStyle: style, compatibleWith: label.traitCollection)
        let font = UIFont.systemFont(ofSize: base.pointSize, weight: weight)
        let paragraph = NSMutableParagraphStyle()
        paragraph.hyphenationFactor = 0
        paragraph.lineBreakMode = breaksWords ? .byCharWrapping : .byWordWrapping
        paragraph.alignment = .left
        label.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: UIColor(color),
                .paragraphStyle: paragraph,
            ]
        )
        label.accessibilityIdentifier = identifier
        label.accessibilityLabel = text
    }
}
