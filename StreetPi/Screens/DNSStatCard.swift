import SwiftUI

struct DNSStatCard: View {
    var value: String
    var title: String
    var line: String
    var theme: StreetTheme

    var body: some View {
        VStack(alignment: .leading, spacing: Rhythm.tight) {
            Text(value)
                .font(.system(.title, design: .rounded).bold())
                .foregroundStyle(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(title)
                .font(.headline)
                .foregroundStyle(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
            Text(line)
                .font(.subheadline)
                .foregroundStyle(theme.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Rhythm.line)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(theme.hairline, lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}
