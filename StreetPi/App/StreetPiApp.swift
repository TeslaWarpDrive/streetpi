import SwiftUI

@main
struct StreetPiApp: App {
    var body: some Scene {
        WindowGroup {
            RootView(now: .now)
                .preferredColorScheme(.dark)
        }
    }
}
