import SwiftUI

/// Room above the phone tab bar. The bar floats over the page, so each screen
/// keeps its own inset instead of drawing cards and type underneath it.
enum TabClearance {
    /// Extra space past the system inset. Enough to lift the last line off the bar
    /// on a small phone without covering the percent that sits just above it.
    static let phoneBar: CGFloat = 20

    /// Sheets and confirmations sit over the bar, so they keep a taller inset.
    static let sheet: CGFloat = 49
}

extension View {
    /// Inset a phone page above the tab bar. A wide window uses the sidebar, so it stays put.
    func clearsPhoneTabBar(wide: Bool) -> some View {
        modifier(PhoneTabClearance(wide: wide))
    }
}

/// A one-point mark a test can find when it scrolls a page.
struct ScrollAnchor: UIViewRepresentable {
    var name: String

    func makeUIView(context: Context) -> ScrollAnchorView {
        let view = ScrollAnchorView()
        view.accessibilityIdentifier = name
        return view
    }

    func updateUIView(_ view: ScrollAnchorView, context: Context) {
        view.accessibilityIdentifier = name
    }
}

final class ScrollAnchorView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        isAccessibilityElement = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }
}

private struct PhoneTabClearance: ViewModifier {
    var wide: Bool

    func body(content: Content) -> some View {
        if wide {
            content
        } else {
            content.padding(.bottom, TabClearance.phoneBar)
        }
    }
}
