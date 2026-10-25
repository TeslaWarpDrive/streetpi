import StreetPiCore
import SwiftUI

/// The big percent on the ad-blocker detail, with the same fraction line as House.
struct DNSBlockerHero: View {
    var share: LookupShare
    var enabled: Bool
    var blockingLine: String
    var theme: StreetTheme

    var body: some View {
        VStack(alignment: .leading, spacing: Rhythm.line) {
            Text(share.percentText)
                .font(.system(.largeTitle, design: .rounded).bold())
                .foregroundStyle(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            HStack(alignment: .firstTextBaseline, spacing: Rhythm.line) {
                Circle()
                    .fill(enabled ? theme.calm : theme.attention)
                    .frame(width: 10, height: 10)
                    .accessibilityHidden(true)
                Text(enabled ? "Blocking is on" : blockingLine)
                    .font(.title3)
                    .foregroundStyle(theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(share.fractionLine)
                .font(.body)
                .foregroundStyle(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
