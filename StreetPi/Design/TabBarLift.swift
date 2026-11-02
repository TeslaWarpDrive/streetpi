import SwiftUI
import UIKit

/// Asks the page to stay above the floating tab bar.
/// The phone scroll view was drawing through the bar, so the lower half of a card
/// counted as visible while it sat under the bar. One extra bottom inset, measured
/// from the bar, ends the page at the top of the bar.
struct TabBarLift: ViewModifier {
    func body(content: Content) -> some View {
        content.background {
            TabBarLiftProbe()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

private struct TabBarLiftProbe: UIViewRepresentable {
    func makeUIView(context: Context) -> Probe {
        let view = Probe()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.isAccessibilityElement = false
        return view
    }

    func updateUIView(_ uiView: Probe, context: Context) {
        uiView.resolve()
    }

    final class Probe: UIView {
        private var didInset = false

        override func didMoveToWindow() {
            super.didMoveToWindow()
            resolve()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            resolve()
        }

        func resolve() {
            guard didInset == false, let window, let bar = Self.tabBar(in: window) else { return }
            guard let controller = hostController() else { return }
            let barFrame = bar.convert(bar.bounds, to: window)
            guard barFrame.minY > window.bounds.midY, barFrame.height > 20 else { return }
            let cover = window.bounds.maxY - barFrame.minY
            let safe = controller.view.safeAreaInsets.bottom
            let short = cover - safe
            guard short > 1 else {
                didInset = true
                return
            }
            controller.additionalSafeAreaInsets.bottom += short
            didInset = true
        }

        private func hostController() -> UIViewController? {
            var responder: UIResponder? = self
            while let next = responder?.next {
                if let controller = next as? UIViewController {
                    return controller
                }
                responder = next
            }
            return nil
        }

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
    }
}

extension View {
    /// Phone pages only. The iPad uses a sidebar and has no bottom bar.
    func endsAboveTabBar() -> some View {
        modifier(TabBarLift())
    }
}
