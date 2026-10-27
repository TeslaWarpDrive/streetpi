import StreetPiCore
import SwiftUI

/// The Pi's four readings as rings. Each keeps its label and a plain word.
/// Phones show two across, the iPad four. Accessibility sizes turn each ring into a labelled row.
struct MachineRings: View {
    var machine: MachineReading
    /// Opens the day chart. Nil leaves the rings as readings only.
    var onOpen: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        AfterglowTileGrid(
            spacing: AfterglowShape.line,
            minimumColumnWidth: dynamicTypeSize.isAccessibilitySize ? 10_000 : AfterglowShape.cardFloor,
            maximumColumns: dynamicTypeSize.isAccessibilitySize ? 1 : 4
        ) {
            ForEach(readings) { reading in
                ring(reading)
            }
        }
    }

    @ViewBuilder
    private func ring(_ reading: RingReading) -> some View {
        let gauge = RingGauge(
            label: reading.label,
            value: reading.value,
            spoken: reading.spoken,
            fraction: reading.fraction,
            symbol: reading.symbol,
            word: reading.word,
            tone: reading.tone
        )
        if let onOpen {
            Button {
                onOpen()
            } label: {
                gauge
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(reading.spoken)
            .accessibilityHint("Opens the last day.")
        } else {
            gauge
        }
    }

    private var readings: [RingReading] {
        var list: [RingReading] = []
        if let cpu = machine.cpuUsedFraction {
            let word = ReadingText.processorWord(cpu)
            list.append(
                RingReading(
                    id: "cpu",
                    label: "Processor",
                    value: ReadingText.percent(cpu),
                    spoken: "Processor, \(spokenPercent(cpu)), \(word)",
                    fraction: cpu,
                    symbol: "gauge.medium",
                    word: word,
                    tone: cpu >= MachineLimits.processorBusy ? .attention : .calm
                )
            )
        }
        if let temperature = machine.temperatureCelsius {
            let word = ReadingText.warmth(temperature)
            list.append(
                RingReading(
                    id: "temperature",
                    label: "Temperature",
                    value: ReadingText.celsius(temperature),
                    spoken: "Temperature, \(Int(temperature.rounded())) degrees, \(word)",
                    fraction: min(max(temperature / 100, 0), 1),
                    symbol: "thermometer.medium",
                    word: word,
                    tone: warmthTone(temperature)
                )
            )
        }
        if let memory = machine.memoryUsedFraction {
            let word = ReadingText.roomWord(memory, limit: MachineLimits.memoryAttention)
            list.append(
                RingReading(
                    id: "memory",
                    label: "Memory",
                    value: ReadingText.percent(memory),
                    spoken: "Memory, \(spokenPercent(memory)), \(word)",
                    fraction: memory,
                    symbol: "memorychip",
                    word: word,
                    tone: memory >= MachineLimits.memoryAttention ? .attention : .calm
                )
            )
        }
        if let disk = machine.diskUsedFraction {
            let word = ReadingText.roomWord(disk, limit: MachineLimits.diskAttention)
            list.append(
                RingReading(
                    id: "disk",
                    label: "Disk",
                    value: ReadingText.percent(disk),
                    spoken: "Disk, \(spokenPercent(disk)), \(word)",
                    fraction: disk,
                    symbol: "internaldrive",
                    word: word,
                    tone: disk >= MachineLimits.diskAttention ? .attention : .calm
                )
            )
        }
        return list
    }

    private func warmthTone(_ degrees: Double) -> PlainEnglishStatus.Tone {
        if degrees >= MachineLimits.hotCelsius {
            return .problem
        }
        if degrees >= MachineLimits.warmCelsius {
            return .attention
        }
        return .calm
    }

    private func spokenPercent(_ fraction: Double) -> String {
        "\(Int((fraction * 100).rounded())) percent"
    }
}

private struct RingReading: Identifiable {
    var id: String
    var label: String
    var value: String
    var spoken: String
    var fraction: Double
    var symbol: String
    var word: String
    var tone: PlainEnglishStatus.Tone
}
