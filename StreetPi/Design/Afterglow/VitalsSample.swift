import StreetPiCore
import SwiftUI

struct VitalsSample: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: AfterglowShape.line) {
            KickerLabel(text: "Vitals")
            AfterglowTileGrid(
                spacing: AfterglowShape.line,
                minimumColumnWidth: dynamicTypeSize.isAccessibilitySize ? 10_000 : AfterglowShape.cardFloor,
                maximumColumns: 4
            ) {
                RingGauge(
                    label: "Processor",
                    value: ReadingText.percent(0.18),
                    spoken: "Processor, 18 percent",
                    fraction: 0.18,
                    symbol: "gauge.medium",
                    word: nil,
                    tone: .calm
                )
                RingGauge(
                    label: "Temperature",
                    value: ReadingText.celsius(47.2),
                    spoken: "Temperature, Cool, 47 degrees",
                    fraction: 0.47,
                    symbol: "thermometer.medium",
                    word: ReadingText.warmth(47.2),
                    tone: .calm
                )
                RingGauge(
                    label: "Memory",
                    value: ReadingText.percent(0.41),
                    spoken: "Memory, 41 percent",
                    fraction: 0.41,
                    symbol: "memorychip",
                    word: nil,
                    tone: .calm
                )
                RingGauge(
                    label: "Disk",
                    value: ReadingText.percent(0.22),
                    spoken: "Disk, 22 percent",
                    fraction: 0.22,
                    symbol: "internaldrive",
                    word: nil,
                    tone: .calm
                )
            }
        }
    }
}
