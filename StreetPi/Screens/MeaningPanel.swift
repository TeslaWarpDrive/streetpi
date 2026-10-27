import StreetPiCore
import SwiftUI

/// "What this means", in one paragraph.
struct MeaningPanel: View {
    var share: LookupShare

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: AfterglowShape.line) {
            Label("What this means", systemImage: "info.circle")
                .font(.headline)
                .foregroundStyle(palette.ink)
                .labelStyle(.titleAndIcon)
                .accessibilityAddTraits(.isHeader)
            Text(AdBlockerCopy.meaning(share))
                .font(.body)
                .foregroundStyle(palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AfterglowShape.page)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.panel, in: RoundedRectangle(cornerRadius: AfterglowShape.panel, style: .continuous))
    }
}
