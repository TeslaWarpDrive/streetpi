import StreetPiCore
import SwiftUI

/// Lookups, how many were stopped, and the generated fraction line.
struct DNSMeaningCard: View {
    var share: LookupShare
    var theme: StreetTheme

    var body: some View {
        VStack(alignment: .leading, spacing: Rhythm.line) {
            Text("What this means")
                .font(.headline)
                .foregroundStyle(theme.ink)
                .accessibilityAddTraits(.isHeader)
            Text("Your devices looked up \(share.lookups) names in the last 24 hours.")
                .font(.body)
                .foregroundStyle(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text("\(share.stopped) of those were stopped.")
                .font(.body)
                .foregroundStyle(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(share.fractionLine)
                .font(.body)
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Rhythm.line)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(theme.hairline, lineWidth: 1)
        }
    }
}
