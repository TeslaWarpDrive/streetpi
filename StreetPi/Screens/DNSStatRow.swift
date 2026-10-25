import StreetPiCore
import SwiftUI

/// Stopped, lookups, and the last hour. Each number has a plain-English line.
struct DNSStatRow: View {
    var share: LookupShare
    var theme: StreetTheme

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let minimum: CGFloat = dynamicTypeSize.isAccessibilitySize ? 10_000 : 150
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: minimum), spacing: Rhythm.line)],
            alignment: .leading,
            spacing: Rhythm.line
        ) {
            DNSStatCard(
                value: "\(share.stopped)",
                title: "Stopped",
                line: "Stopped in the last 24 hours",
                theme: theme
            )
            DNSStatCard(
                value: "\(share.lookups)",
                title: "Lookups",
                line: "Names your devices asked for",
                theme: theme
            )
            DNSStatCard(
                value: lastHour,
                title: "Last hour",
                line: "Stopped in the last hour",
                theme: theme
            )
        }
    }

    private var lastHour: String {
        guard let count = share.lastHourStopped else { return "—" }
        return "\(count)"
    }
}
