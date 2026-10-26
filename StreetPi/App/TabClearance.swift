import SwiftUI

/// Room above the phone tab bar. The bar floats over the page, so each screen
/// keeps its own inset instead of drawing cards and type underneath it.
enum TabClearance {
    /// Extra space past the system inset. Enough to lift the last line off the bar
    /// on a small phone without covering the percent that sits just above it.
    static let phoneBar: CGFloat = 20

    /// A short ground gap above the one phone bar. The page scrolls; this does not
    /// hide the next row.
    static let cardBar: CGFloat = 12

    /// Sheets and confirmations sit over the bar, so they keep a taller inset.
    static let sheet: CGFloat = 49
}

extension View {
    /// Inset a phone page above the tab bar. A wide window uses the sidebar, so it stays put.
    func clearsPhoneTabBar(wide: Bool, inset: CGFloat = TabClearance.phoneBar) -> some View {
        modifier(PhoneTabClearance(wide: wide, inset: inset))
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

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: ScrollAnchorView, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 1, height: proposal.height ?? 1)
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
    var inset: CGFloat

    func body(content: Content) -> some View {
        if wide {
            content
        } else if inset == TabClearance.phoneBar {
            content.padding(.bottom, inset)
        } else {
            content
                .padding(.bottom, inset)
                .background(StreetTheme.house.background)
        }
    }
}
