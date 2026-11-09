import StreetPiCore
import SwiftUI
import UIKit

/// The return key the old one-line field used.
enum LargeTypeSubmit {
    case done
    case next
    case `return`

    var uiKey: UIReturnKeyType {
        switch self {
        case .done:
            .done
        case .next:
            .next
        case .return:
            .default
        }
    }
}

/// A prompt and a value that wrap at the largest text sizes.
/// The example is the field's own prompt. An empty field does not draw it on a second line.
struct LargeTypeEntry: View {
    var prompt: String
    @Binding var text: String
    var monospaced: Bool
    var ink: Color
    var promptInk: Color
    var submit: LargeTypeSubmit
    var onBeginEditing: (() -> Void)?
    var onSubmit: (() -> Void)?

    init(
        prompt: String,
        text: Binding<String>,
        monospaced: Bool = false,
        ink: Color,
        promptInk: Color,
        submit: LargeTypeSubmit = .return,
        onBeginEditing: (() -> Void)? = nil,
        onSubmit: (() -> Void)? = nil
    ) {
        self.prompt = prompt
        self._text = text
        self.monospaced = monospaced
        self.ink = ink
        self.promptInk = promptInk
        self.submit = submit
        self.onBeginEditing = onBeginEditing
        self.onSubmit = onSubmit
    }

    var body: some View {
        editor
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    LargeTypeLabel(text: prompt, monospaced: monospaced, style: .body, color: promptInk)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
    }

    private var editor: some View {
        LargeTypeEditor(
            text: $text,
            prompt: prompt,
            monospaced: monospaced,
            ink: UIColor(ink),
            submit: submit,
            onBeginEditing: onBeginEditing,
            onSubmit: onSubmit
        )
    }
}

/// A label that breaks after a dot and does not hyphenate a run the row can hold.
struct LargeTypeLabel: UIViewRepresentable {
    var text: String
    var monospaced: Bool
    var style: UIFont.TextStyle
    var color: Color

    func makeUIView(context: Context) -> LargeTypeLine {
        let label = LargeTypeLine()
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        label.setContentHuggingPriority(.required, for: .vertical)
        refresh(label)
        return label
    }

    func updateUIView(_ label: LargeTypeLine, context: Context) {
        refresh(label)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: LargeTypeLine, context: Context) -> CGSize? {
        let font = LargeTypeDrawing.font(style: style, monospaced: monospaced, traits: uiView.traitCollection)
        let limit = LargeTypeDrawing.limit(proposal.width)
        let height = LargeTypeDrawing.height(of: text, font: font, width: limit)
        let natural = (text as NSString).size(withAttributes: [.font: font]).width
        let width = min(max(ceil(natural), 1), limit)
        return CGSize(width: width, height: height)
    }

    private func refresh(_ label: LargeTypeLine) {
        label.source = text
        label.monospaced = monospaced
        label.textStyle = style
        label.ink = UIColor(color)
        label.refresh()
    }
}

/// Draws a largest-type line with hyphenation off.
private final class LargeTypeLine: UILabel {
    var source = ""
    var monospaced = false
    var textStyle: UIFont.TextStyle = .body
    var ink = UIColor.label
    private var stamp = ""
    private var painted = UIColor.label

    override init(frame: CGRect) {
        super.init(frame: frame)
        numberOfLines = 0
        lineBreakMode = .byWordWrapping
        adjustsFontForContentSizeCategory = true
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Large type label is built in code")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        refresh()
    }

    func refresh() {
        let width = bounds.width > 1 ? bounds.width : CGFloat.greatestFiniteMagnitude
        let font = LargeTypeDrawing.font(style: textStyle, monospaced: monospaced, traits: traitCollection)
        let mark = "\(source)|\(width)|\(font.pointSize)|\(monospaced)"
        guard mark != stamp || painted != ink else { return }
        stamp = mark
        painted = ink
        attributedText = LargeTypeDrawing.attributed(source, font: font, color: ink, width: width)
        accessibilityLabel = source
    }
}

/// An editor that wraps a long token by character and never inserts a hyphen.
private struct LargeTypeEditor: UIViewRepresentable {
    @Binding var text: String
    var prompt: String
    var monospaced: Bool
    var ink: UIColor
    var submit: LargeTypeSubmit
    var onBeginEditing: (() -> Void)?
    var onSubmit: (() -> Void)?

    func makeCoordinator() -> EntryCoordinator {
        EntryCoordinator(text: $text, onBeginEditing: onBeginEditing, onSubmit: onSubmit)
    }

    func makeUIView(context: Context) -> WrappingTextView {
        let view = WrappingTextView()
        view.delegate = context.coordinator
        apply(view)
        return view
    }

    func updateUIView(_ view: WrappingTextView, context: Context) {
        context.coordinator.text = $text
        context.coordinator.onBeginEditing = onBeginEditing
        context.coordinator.onSubmit = onSubmit
        if view.text != text {
            view.text = text
        }
        apply(view)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: WrappingTextView, context: Context) -> CGSize? {
        apply(uiView)
        let limit = LargeTypeDrawing.limit(proposal.width)
        let font = uiView.font ?? UIFont.preferredFont(forTextStyle: .body)
        let sample = uiView.text ?? ""
        if sample.isEmpty {
            let height = LargeTypeDrawing.height(of: uiView.prompt, font: font, width: limit)
            return CGSize(width: limit, height: height)
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.hyphenationFactor = 0
        paragraph.lineBreakMode = .byCharWrapping
        let rect = (sample as NSString).boundingRect(
            with: CGSize(width: limit, height: 10_000),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font, .paragraphStyle: paragraph],
            context: nil
        )
        return CGSize(width: limit, height: max(ceil(rect.height), ceil(font.lineHeight)))
    }

    private func apply(_ view: WrappingTextView) {
        let font = LargeTypeDrawing.font(style: .body, monospaced: monospaced, traits: view.traitCollection)
        let paragraph = NSMutableParagraphStyle()
        paragraph.hyphenationFactor = 0
        paragraph.lineBreakMode = .byCharWrapping
        view.prompt = prompt
        view.font = font
        view.textColor = ink
        view.returnKeyType = submit.uiKey
        view.accessibilityLabel = text.isEmpty ? prompt : nil
        view.typingAttributes = [
            .font: font,
            .foregroundColor: ink,
            .paragraphStyle: paragraph,
        ]
    }
}

/// Grows with its text. Return submits instead of adding a line.
@MainActor
private final class WrappingTextView: UITextView {
    var prompt = ""

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        backgroundColor = .clear
        isScrollEnabled = false
        textContainerInset = .zero
        self.textContainer.lineFragmentPadding = 0
        self.textContainer.lineBreakMode = .byCharWrapping
        self.textContainer.widthTracksTextView = true
        layoutManager.hyphenationFactor = 0
        autocapitalizationType = .none
        autocorrectionType = .no
        spellCheckingType = .no
        keyboardType = .URL
        returnKeyType = .default
        adjustsFontForContentSizeCategory = true
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .vertical)
        setContentHuggingPriority(.required, for: .vertical)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Large type editor is built in code")
    }
}

@MainActor
private final class EntryCoordinator: NSObject, UITextViewDelegate {
    var text: Binding<String>
    var onBeginEditing: (() -> Void)?
    var onSubmit: (() -> Void)?

    init(text: Binding<String>, onBeginEditing: (() -> Void)?, onSubmit: (() -> Void)?) {
        self.text = text
        self.onBeginEditing = onBeginEditing
        self.onSubmit = onSubmit
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        onBeginEditing?()
    }

    func textViewDidChange(_ textView: UITextView) {
        text.wrappedValue = textView.text ?? ""
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText: String) -> Bool {
        guard replacementText == "\n" else { return true }
        if textView.returnKeyType == .done || textView.returnKeyType == .next {
            onSubmit?()
        }
        if textView.returnKeyType != .next {
            textView.resignFirstResponder()
        }
        return false
    }
}

/// Shared measurement for a largest-type label. Hyphenation stays off.
private enum LargeTypeDrawing {
    static func font(style: UIFont.TextStyle, monospaced: Bool, traits: UITraitCollection) -> UIFont {
        let base = UIFont.preferredFont(forTextStyle: style, compatibleWith: traits)
        guard monospaced, let designed = base.fontDescriptor.withDesign(.monospaced) else {
            return base
        }
        return UIFont(descriptor: designed, size: base.pointSize)
    }

    static func limit(_ width: CGFloat?) -> CGFloat {
        guard let width, width.isFinite, width > 1 else { return 10_000 }
        return width
    }

    static func attributed(_ text: String, font: UIFont, color: UIColor, width: CGFloat) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.hyphenationFactor = 0
        paragraph.lineBreakMode = .byWordWrapping
        return NSAttributedString(
            string: wrapped(text, font: font, width: width),
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraph,
            ]
        )
    }

    static func height(of text: String, font: UIFont, width: CGFloat) -> CGFloat {
        let sample = attributed(text, font: font, color: .label, width: width)
        let rect = sample.boundingRect(
            with: CGSize(width: width, height: 10_000),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return max(ceil(rect.height), ceil(font.lineHeight))
    }

    static func wrapped(_ text: String, font: UIFont, width: CGFloat) -> String {
        let row = width.isFinite && width > 1 ? width : CGFloat.greatestFiniteMagnitude
        return LargeTypeWrap.allowingWrap(text) { run in
            let measured = (run as NSString).size(withAttributes: [.font: font]).width
            return measured <= row + 0.5
        }
    }
}
