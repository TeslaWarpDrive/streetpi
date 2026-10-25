import SwiftUI

/// Adds the pause action only while blocking can be paused.
struct PauseBlockerAction: ViewModifier {
    var enabled: Bool
    var action: () -> Void

    func body(content: Content) -> some View {
        if enabled {
            content.accessibilityAction(named: Text("Pause ad blocker"), action)
        } else {
            content
        }
    }
}
