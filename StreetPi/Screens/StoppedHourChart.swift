import StreetPiCore
import SwiftUI

/// Stopped lookups for each of the last 24 hours.
struct StoppedHourChart: View {
    var samples: [DayChartSample]
    var stopped: Int
    var theme: StreetTheme

    var body: some View {
        VStack(alignment: .leading, spacing: Rhythm.line) {
            Text("Stopped each hour, last 24 hours")
                .font(.headline)
                .foregroundStyle(theme.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            bars
            HStack(spacing: Rhythm.line) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(theme.accent)
                    .frame(width: 12, height: 12)
                    .accessibilityHidden(true)
                Text("Stopped")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondary)
            }
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Stopped each hour, last 24 hours. \(stopped) stopped.")
    }

    private var bars: some View {
        let peak = max(1, samples.map(\.blocked).max() ?? 1)
        return HStack(alignment: .bottom, spacing: 3) {
            ForEach(samples) { sample in
                bar(sample, peak: peak)
            }
        }
        .frame(height: 120)
        .accessibilityHidden(true)
    }

    private func bar(_ sample: DayChartSample, peak: Int) -> some View {
        let height = CGFloat(sample.blocked) / CGFloat(peak) * 120
        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(sample.blocked == 0 ? theme.hairline : theme.accent)
                .frame(height: max(height, sample.blocked == 0 ? 2 : 4))
        }
        .frame(maxWidth: .infinity)
    }
}
