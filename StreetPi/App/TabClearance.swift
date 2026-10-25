import SwiftUI

/// Room above the phone tab bar. The bar floats over the page, so each screen
/// keeps its own inset instead of drawing cards and type underneath it.
enum TabClearance {
    /// Tall enough for the phone bar on a home-button phone and a phone with a home indicator.
    static let phoneBar: CGFloat = 100
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
