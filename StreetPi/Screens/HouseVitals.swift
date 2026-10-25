import StreetPiCore
import SwiftUI

/// Processor, temperature, memory, and disk. The grid drops a column when the words need the width.
struct HouseVitals: View {
    var machine: MachineReading

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: AfterglowShape.line) {
            KickerLabel(text: "Vitals")
            AfterglowTileGrid(
                spacing: AfterglowShape.line,
                minimumColumnWidth: dynamicTypeSize.isAccessibilitySize ? 10_000 : AfterglowShape.cardFloor,
                maximumColumns: dynamicTypeSize.isAccessibilitySize ? 1 : 4
            ) {
                if let cpu = machine.cpuUsedFraction {
                    RingGauge(
                        label: "Processor",
                        value: ReadingText.percent(cpu),
                        spoken: spokenPercent("Processor", cpu),
                        fraction: cpu,
                        symbol: "gauge.medium",
                        word: nil,
                        tone: .calm
                    )
                }
                if let temperature = machine.temperatureCelsius {
                    RingGauge(
                        label: "Temperature",
                        value: ReadingText.celsius(temperature),
                        spoken: temperatureSpoken(temperature),
                        fraction: min(max(temperature / 100, 0), 1),
                        symbol: "thermometer.medium",
                        word: ReadingText.warmth(temperature),
                        tone: temperatureTone(temperature)
                    )
                }
                if let memory = machine.memoryUsedFraction {
                    RingGauge(
                        label: "Memory",
                        value: ReadingText.percent(memory),
                        spoken: spokenPercent("Memory", memory),
                        fraction: memory,
                        symbol: "memorychip",
                        word: memory >= MachineLimits.memoryAttention ? "Low" : nil,
                        tone: memory >= MachineLimits.memoryAttention ? .attention : .calm
                    )
                }
                if let disk = machine.diskUsedFraction {
                    RingGauge(
                        label: "Disk",
                        value: ReadingText.percent(disk),
                        spoken: spokenPercent("Disk", disk),
                        fraction: disk,
                        symbol: "internaldrive",
                        word: disk >= MachineLimits.diskAttention ? "Almost full" : nil,
                        tone: disk >= MachineLimits.diskAttention ? .attention : .calm
                    )
                }
            }
        }
    }

    private func temperatureTone(_ degrees: Double) -> PlainEnglishStatus.Tone {
        if degrees >= MachineLimits.hotCelsius {
            return .problem
        }
        if degrees >= MachineLimits.warmCelsius {
            return .attention
        }
        return .calm
    }

    private func temperatureSpoken(_ degrees: Double) -> String {
        let rounded = Int(degrees.rounded())
        return "Temperature, \(ReadingText.warmth(degrees)), \(rounded) degrees"
    }

    private func spokenPercent(_ label: String, _ fraction: Double) -> String {
        let value = Int((fraction * 100).rounded())
        return "\(label), \(value) percent"
    }
}
