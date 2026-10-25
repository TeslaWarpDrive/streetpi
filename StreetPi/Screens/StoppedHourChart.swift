import StreetPiCore
import SwiftUI

/// Bars for ads and trackers stopped in each of the last 24 hours.
struct StoppedHourChart: View {
    var hours: [HomeHourBar]

    @Environment(\.afterglowPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: AfterglowShape.line) {
            Text("Stopped each hour, last 24 hours")
                .font(.headline)
                .foregroundStyle(palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if hours.isEmpty {
                Text("No hourly reading yet.")
                    .font(.body)
                    .foregroundStyle(palette.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                bars
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(spoken)
    }

    private var spoken: String {
        guard let peak = hours.map(\.stopped).max(), hours.isEmpty == false else {
            return "Stopped each hour, last 24 hours. No hourly reading yet."
        }
        return "Stopped each hour, last 24 hours. The busiest hour stopped \(peak)."
    }

    private var bars: some View {
        let peak = max(1, hours.map(\.stopped).max() ?? 1)
        return HStack(alignment: .bottom, spacing: 3) {
            ForEach(hours) { hour in
                bar(hour, peak: peak)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .accessibilityHidden(true)
    }

    private func bar(_ hour: HomeHourBar, peak: Int) -> some View {
        let height = CGFloat(hour.stopped) / CGFloat(peak) * 120
        return VStack(spacing: 0) {
            Spacer(minLength: 0)
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(palette.accent)
                .frame(height: max(height, hour.stopped == 0 ? 2 : 4))
        }
        .frame(maxWidth: .infinity)
    }
}
