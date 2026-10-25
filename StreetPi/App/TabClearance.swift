import SwiftUI

/// The phone tab strip is a sibling of the page, so the page ends where the strip starts.
/// `phoneBar` is only the fallback a test uses when it cannot find that strip.
enum TabClearance {
    static let phoneBar: CGFloat = 49

    /// Sheets and confirmations sit over the bar, so they keep a taller inset.
    static let sheet: CGFloat = 49
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

/// The phone strip and the iPad sidebar sit beside the page, so the page is not padded.
struct ShellChrome<Page: View>: View {
    var wide: Bool
    @Binding var selection: HouseTab
    var roomy: Bool
    @ViewBuilder var page: () -> Page

    var body: some View {
        if wide {
            HStack(alignment: .top, spacing: 0) {
                AccessibleTabStrip(selection: $selection, scrollsHorizontally: false)
                    .frame(minWidth: roomy ? 280 : 200, maxWidth: roomy ? 340 : 280)
                    .frame(maxHeight: .infinity, alignment: .top)
                laidOut
            }
        } else {
            VStack(spacing: 0) {
                laidOut
                AccessibleTabStrip(selection: $selection, scrollsHorizontally: true)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var laidOut: some View {
        page()
            .tabViewStyle(.tabBarOnly)
            .toolbar(.hidden, for: .tabBar)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
