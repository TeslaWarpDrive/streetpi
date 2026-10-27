import SwiftUI

/// A quiet hint under the tiles. It sits back so the tiles lead.
struct HouseFooter: View {
    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        Text("Tap a tile to open it. Hold the ad blocker to pause it.")
            .font(.caption2)
            .foregroundStyle(palette.tertiary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .reportsLayout("page-end")
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, AfterglowShape.line)
    }
}
