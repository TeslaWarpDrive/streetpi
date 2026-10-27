import SwiftUI

struct HouseFooter: View {
    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        Text("Tap a tile to open it. Hold the ad blocker to pause it.")
            .font(.caption)
            .foregroundStyle(palette.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .reportsLayout("page-end")
            .frame(maxWidth: .infinity, alignment: .center)
    }
}
