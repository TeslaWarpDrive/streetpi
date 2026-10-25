import SwiftUI

/// Preview-only screen. It is not in the tab bar and it does not change navigation.
struct ComponentGallery: View {
    var body: some View {
        AfterglowScope {
            ScrollView {
                ComponentBoard()
            }
            .scrollIndicators(.hidden)
        }
    }
}

#Preview("Dark") {
    ComponentGallery()
        .preferredColorScheme(.dark)
        .environment(\.streetPiStill, true)
}

#Preview("Largest type") {
    ComponentGallery()
        .preferredColorScheme(.dark)
        .environment(\.dynamicTypeSize, .accessibility5)
        .environment(\.streetPiStill, true)
}
