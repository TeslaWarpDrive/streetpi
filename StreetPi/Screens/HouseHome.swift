import StreetPiCore
import SwiftUI

/// House: kicker, link, aura, headline, Briefing, vitals, and rooms.
struct HouseHome: View {
    var snapshot: HouseholdSnapshot?
    var status: PlainEnglishStatus
    var lines: [String]
    var groups: [GroupBrief]
    var alertCount: Int
    var now: Date
    var wide: Bool
    var onRefresh: @MainActor () async -> Void
    var onAlerts: () -> Void
    var onOpen: (HouseGroup) -> Void

    @Environment(\.afterglowGate) private var gate
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showGlint = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: dynamicTypeSize.isAccessibilitySize ? AfterglowShape.line : AfterglowShape.block) {
                header
                briefing
                if let machine = snapshot?.machine, hasVitals(machine) {
                    HouseVitals(machine: machine)
                }
                if groups.isEmpty == false {
                    HouseRooms(groups: groups, snapshot: snapshot, onOpen: onOpen)
                }
            }
            .padding(.horizontal, AfterglowShape.page)
            .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? AfterglowShape.tight : AfterglowShape.block)
            .frame(maxWidth: wide ? 880 : 560)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await refresh()
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: AfterglowShape.line) {
                heading
                Spacer(minLength: AfterglowShape.line)
                AlertsBell(alertCount: alertCount, action: onAlerts)
            }
            VStack(alignment: .leading, spacing: AfterglowShape.line) {
                HStack(alignment: .center, spacing: AfterglowShape.line) {
                    KickerLabel(text: "Raspberry Pi Stats")
                    Spacer(minLength: AfterglowShape.line)
                    AlertsBell(alertCount: alertCount, action: onAlerts)
                }
                StatusChip(title: status.linkLine, tone: status.tone, symbol: "house.fill")
            }
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: AfterglowShape.tight) {
            KickerLabel(text: "Raspberry Pi Stats")
            StatusChip(title: status.linkLine, tone: status.tone, symbol: "house.fill")
        }
    }

    private var briefing: some View {
        VStack(alignment: .leading, spacing: AfterglowShape.line) {
            StatusHeadline(title: status.headline, accentWord: accentWord, tone: status.tone)
            GlassPanel(showsGlint: showGlint) {
                VStack(alignment: .leading, spacing: AfterglowShape.line) {
                    if spoken.isEmpty == false {
                        ComposeText(lines: spoken)
                    }
                    MonoReading(text: updated)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var accentWord: String {
        HeadlineAccent.word(in: status.headline)
    }

    private var spoken: [String] {
        if lines.isEmpty == false {
            return lines
        }
        if let detail = status.detail, detail.isEmpty == false {
            return [detail]
        }
        return []
    }

    private var updated: String {
        guard let snapshot else { return "No reading yet" }
        return "Updated \(AgePhrase.english(from: snapshot.referenceDate, to: now))"
    }

    private func hasVitals(_ machine: MachineReading) -> Bool {
        machine.cpuUsedFraction != nil
            || machine.temperatureCelsius != nil
            || machine.memoryUsedFraction != nil
            || machine.diskUsedFraction != nil
    }

    private func refresh() async {
        showGlint = true
        defer { showGlint = false }
        await onRefresh()
        if gate.holdsMotion {
            try? await Task.sleep(for: .seconds(AfterglowMotion.slow))
        }
    }
}

/// The word in a headline that takes the Aurora sheen.
enum HeadlineAccent {
    static func word(in title: String) -> String {
        let folded = title.lowercased()
        let keys = [
            "good", "look", "down", "hot", "paused", "full", "memory",
            "answering", "trouble", "warmer", "yet",
        ]
        for key in keys where folded.contains(key) {
            return key
        }
        return ""
    }
}
