import SwiftUI

/// Accent-tinted tile icon. Decorative. The tile button carries the spoken name.
struct IconChip: View {
    var systemImage: String

    @Environment(\.afterglowPalette) private var palette
    @ScaledMetric(relativeTo: .body) private var side = 36

    var body: some View {
        Image(systemName: systemImage)
            .font(.title3)
            .foregroundStyle(palette.accent)
            .frame(width: max(side, 36), height: max(side, 36))
            .background(palette.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(palette.accent.opacity(0.18), lineWidth: 1)
            }
            .accessibilityHidden(true)
    }
}
