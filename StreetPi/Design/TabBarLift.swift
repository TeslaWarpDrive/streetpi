import SwiftUI
import UIKit

extension Notification.Name {
    /// Posted with a `LiftToken` and a `lift` number after the phone page is measured.
    static let streetPiTabBarLift = Notification.Name("streetpi.tabBarLift")
}

/// One house page. Keeps a measurement from another page from moving this one.
final class LiftToken: NSObject, @unchecked Sendable {}

/// Adds bottom space inside a phone scroll view when the floating tab bar
/// covers more than the scroll view already insets. Cards can then rest fully
/// above the bar. Space the system already provides is left alone.
struct TabBarLift: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var lift: CGFloat = 0
    @State private var token = LiftToken()

    func body(content: Content) -> some View {
        if sizeClass == .regular {
            content
        } else {
            content
                .padding(.bottom, lift)
                .background {
                    TabBarLiftProbe(applied: lift, token: token)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                .onReceive(NotificationCenter.default.publisher(for: .streetPiTabBarLift)) { note in
                    guard let source = note.object as? LiftToken, source === token else { return }
                    guard let raw = note.userInfo?["lift"] as? Double else { return }
                    let next = CGFloat(raw)
                    if abs(next - lift) > 0.5 {
                        lift = next
                    }
                }
        }
    }
}

private struct TabBarLiftProbe: UIViewRepresentable {
    var applied: CGFloat
    var token: LiftToken

    func makeUIView(context: Context) -> Probe {
        let view = Probe()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.isAccessibilityElement = false
        return view
    }

    func updateUIView(_ uiView: Probe, context: Context) {
        uiView.applied = applied
        uiView.token = token
        uiView.resolve()
    }

    final class Probe: UIView {
        var applied: CGFloat = 0
        var token: LiftToken?
        private var reported: CGFloat = -1

        override func didMoveToWindow() {
            super.didMoveToWindow()
            resolve()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            resolve()
        }

        /// Only the part of the bar that the scroll view does not already clear.
        func resolve() {
            guard let window, let bar = Self.tabBar(in: window), let token else { return }
            guard let scroll = Self.mainScroll(in: window) else { return }
            let scrollFrame = scroll.convert(scroll.bounds, to: window)
            let barFrame = bar.convert(bar.bounds, to: window)
            let overlap = max(0, scrollFrame.maxY - barFrame.minY)
            let shortfall = max(0, overlap - scroll.adjustedContentInset.bottom)
            let needed = min(shortfall, Self.cap)
            guard abs(needed - applied) > 0.5, abs(needed - reported) > 0.5 else { return }
            reported = needed
            let value = Double(needed)
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .streetPiTabBarLift,
                    object: token,
                    userInfo: ["lift": value]
                )
            }
        }

        /// Taller than any phone tab bar, so a layout fight cannot grow the gap forever.
        private static let cap: CGFloat = 140

        private static func tabBar(in view: UIView) -> UITabBar? {
            if let bar = view as? UITabBar, bar.isHidden == false, bar.alpha > 0.01, bar.bounds.height > 1 {
                return bar
            }
            for child in view.subviews {
                if let found = tabBar(in: child) {
                    return found
                }
            }
            return nil
        }

        private static func mainScroll(in window: UIWindow) -> UIScrollView? {
            scrolls(in: window)
                .filter { $0.isHidden == false && $0.bounds.height > window.bounds.height * 0.4 }
                .max { $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height }
        }

        private static func scrolls(in view: UIView) -> [UIScrollView] {
            let own = (view as? UIScrollView).map { [$0] } ?? []
            return own + view.subviews.flatMap { scrolls(in: $0) }
        }
    }
}

extension View {
    /// Phone only. The iPad has a sidebar and no bottom bar.
    func endsAboveTabBar() -> some View {
        modifier(TabBarLift())
    }
}
