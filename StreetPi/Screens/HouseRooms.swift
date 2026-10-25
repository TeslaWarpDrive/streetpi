import StreetPiCore
import SwiftUI

/// Rooms on House. Ad blocker and Pi open their tabs. The other rooms keep the current page.
struct HouseRooms: View {
    var groups: [GroupBrief]
    var snapshot: HouseholdSnapshot?
    var onOpen: (HouseGroup) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: AfterglowShape.line) {
            KickerLabel(text: "Rooms")
            GlassGroup(spacing: AfterglowShape.line) {
                AfterglowTileGrid(
                    spacing: AfterglowShape.line,
                    minimumColumnWidth: dynamicTypeSize.isAccessibilitySize ? 10_000 : AfterglowShape.cardFloor,
                    maximumColumns: dynamicTypeSize.isAccessibilitySize ? 1 : 6
                ) {
                    ForEach(groups) { group in
                        RoomTile(
                            title: title(group.id),
                            detail: detail(group),
                            word: word(group),
                            symbol: symbol(group.id),
                            tone: group.tone,
                            prominent: group.id == .adBlockerAndDNS,
                            action: { onOpen(group.id) }
                        )
                    }
                }
            }
        }
    }

    private func title(_ group: HouseGroup) -> String {
        switch group {
        case .adBlockerAndDNS:
            "Ad blocker"
        case .piHealth:
            "Pi"
        default:
            group.title
        }
    }

    private func symbol(_ group: HouseGroup) -> String {
        switch group {
        case .adBlockerAndDNS:
            "shield.lefthalf.filled"
        case .streaming:
            "play.tv"
        case .smartHome:
            "homekit"
        case .remoteHelp:
            "display.and.arrow.down"
        case .internet:
            "globe"
        case .piHealth:
            "cpu"
        case .backups:
            "externaldrive.badge.timemachine"
        }
    }

    private func detail(_ group: GroupBrief) -> String {
        if group.id == .adBlockerAndDNS, let count = snapshot?.dns?.blockedToday {
            return "\(count) blocked today"
        }
        return group.summary
    }

    private func word(_ group: GroupBrief) -> String {
        if group.id == .adBlockerAndDNS, snapshot?.dns?.blockingEnabled == false {
            return "Paused"
        }
        if let row = group.rows.first(where: { $0.state == "Not responding" || $0.state == "Having trouble" }) {
            return row.state
        }
        if let row = group.rows.first {
            return row.state
        }
        if group.id == .piHealth, let degrees = snapshot?.machine?.temperatureCelsius {
            return ReadingText.warmth(degrees)
        }
        switch group.tone {
        case .calm:
            return "Up"
        case .attention:
            return "Look"
        case .problem:
            return "Down"
        }
    }
}
