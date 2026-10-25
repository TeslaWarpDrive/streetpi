import StreetPiCore
import SwiftUI

/// One service at a glance. The word sits with the dot.
struct ServiceSquareTile: View {
    var square: ServiceSquare
    var onOpen: () -> Void

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        Button(action: onOpen) {
            VStack(spacing: AfterglowShape.tight) {
                StatusDot(tone: square.tone)
                Text(square.word)
                    .font(.headline)
                    .foregroundStyle(palette.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: true, vertical: true)
                Text(square.title)
                    .font(.subheadline)
                    .foregroundStyle(palette.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: true, vertical: true)
            }
            .padding(AfterglowShape.line)
            .frame(maxWidth: .infinity, minHeight: 96)
            .background(palette.panel, in: RoundedRectangle(cornerRadius: AfterglowShape.tile, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AfterglowShape.tile, style: .continuous)
                    .strokeBorder(palette.hairline, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(square.title), \(square.word)")
    }
}
