import SwiftUI
import UIKit

/// Pulls a phone page up so its scroll view ends where the floating tab bar starts.
/// The bar covers the bottom of the phone. A card in that strip is not fully on screen.
struct TabBarLift: ViewModifier {
    @State private var lift: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .padding(.bottom, lift)
            .background {
                TabBarLiftProbe(applied: lift) { next in
                    lift = next
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
    }
}

private struct TabBarLiftProbe: UIViewRepresentable {
    var applied: CGFloat
    var onLift: (CGFloat) -> Void

    func makeCoordinator() -> Hop {
        Hop()
    }

    func makeUIView(context: Context) -> Probe {
        let view = Probe()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.isAccessibilityElement = false
        return view
    }

    func updateUIView(_ uiView: Probe, context: Context) {
        context.coordinator.onLift = onLift
        let hop = context.coordinator
        uiView.onNeeded = { value in
            hop.schedule(value)
        }
        uiView.applied = applied
        uiView.resolve()
    }

    /// Carries the measured lift back to SwiftUI after this layout pass.
    final class Hop: @unchecked Sendable {
        var onLift: @MainActor (CGFloat) -> Void = { _ in }
        private var queued: CGFloat = -1

        func schedule(_ value: CGFloat) {
            guard abs(value - queued) > 0.5 else { return }
            queued = value
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    self.onLift(value)
                }
            }
        }
    }

    final class Probe: UIView {
        var applied: CGFloat = 0
        nonisolated(unsafe) var onNeeded: ((CGFloat) -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            resolve()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            resolve()
        }

        /// Padding already applied, plus any of the scroll view still under the bar.
        /// Once the page ends at the bar, that sum stays put.
        func resolve() {
            guard let window, let bar = Self.tabBar(in: window) else { return }
            guard let scroll = Self.mainScroll(in: window) else { return }
            let scrollFrame = scroll.convert(scroll.bounds, to: window)
            let barFrame = bar.convert(bar.bounds, to: window)
            let overlap = max(0, scrollFrame.maxY - barFrame.minY)
            let needed = min(overlap + applied, Self.cap)
            guard abs(needed - applied) > 0.5 else { return }
            onNeeded?(needed)
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
