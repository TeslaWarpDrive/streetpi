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
