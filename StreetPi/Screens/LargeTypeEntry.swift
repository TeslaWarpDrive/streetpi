import SwiftUI
import UIKit

/// A prompt and a value that wrap at the largest text sizes.
/// The system placeholder stays on one line and ends in an ellipsis, so this
/// draws the prompt itself and lets the value grow onto more lines.
struct LargeTypeEntry: View {
    var prompt: String
    @Binding var text: String
    var monospaced = false
    var ink: Color
    var promptInk: Color
    var onSubmit: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: Rhythm.tight) {
            if text.isEmpty {
                Text(LargeTypeWrap.allowingWrap(prompt))
                    .font(fieldFont)
                    .foregroundStyle(promptInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)
            }
            LargeTypeEditor(text: $text, monospaced: monospaced, ink: UIColor(ink), onSubmit: onSubmit)
        }
    }

    private var fieldFont: Font {
        monospaced ? .body.monospaced() : .body
    }
}

/// An editor that wraps a long token by character and never inserts a hyphen.
private struct LargeTypeEditor: UIViewRepresentable {
    @Binding var text: String
    var monospaced: Bool
    var ink: UIColor
    var onSubmit: (() -> Void)?

    func makeCoordinator() -> EntryCoordinator {
        EntryCoordinator(text: $text, onSubmit: onSubmit)
    }

    func makeUIView(context: Context) -> WrappingTextView {
        let view = WrappingTextView()
        view.delegate = context.coordinator
        apply(view)
        return view
    }

    func updateUIView(_ view: WrappingTextView, context: Context) {
        context.coordinator.text = $text
        context.coordinator.onSubmit = onSubmit
        if view.text != text {
            view.text = text
        }
        apply(view)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: WrappingTextView, context: Context) -> CGSize? {
        apply(uiView)
        let width = proposal.width ?? 0
        let limit = width.isFinite && width > 1 ? width : 10_000
        let font = uiView.font ?? UIFont.preferredFont(forTextStyle: .body)
        let sample = uiView.text ?? ""
        guard sample.isEmpty == false else {
            return CGSize(width: limit, height: ceil(font.lineHeight))
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
        let base = UIFont.preferredFont(forTextStyle: .body, compatibleWith: view.traitCollection)
        let font = Self.font(base: base, monospaced: monospaced)
        let paragraph = NSMutableParagraphStyle()
        paragraph.hyphenationFactor = 0
        paragraph.lineBreakMode = .byCharWrapping
        view.font = font
        view.textColor = ink
        view.typingAttributes = [
            .font: font,
            .foregroundColor: ink,
            .paragraphStyle: paragraph,
        ]
    }

    private static func font(base: UIFont, monospaced: Bool) -> UIFont {
        guard monospaced, let designed = base.fontDescriptor.withDesign(.monospaced) else {
            return base
        }
        return UIFont(descriptor: designed, size: base.pointSize)
    }
}

/// Grows with its text. Return submits instead of adding a line.
@MainActor
private final class WrappingTextView: UITextView {
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
        returnKeyType = .done
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
    var onSubmit: (() -> Void)?

    init(text: Binding<String>, onSubmit: (() -> Void)?) {
        self.text = text
        self.onSubmit = onSubmit
    }

    func textViewDidChange(_ textView: UITextView) {
        text.wrappedValue = textView.text ?? ""
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText: String) -> Bool {
        guard replacementText == "\n" else { return true }
        onSubmit?()
        textView.resignFirstResponder()
        return false
    }
}
