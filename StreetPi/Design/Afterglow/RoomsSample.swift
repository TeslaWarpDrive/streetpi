import StreetPiCore
import SwiftUI

struct RoomsSample: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: AfterglowShape.block) {
            VStack(alignment: .leading, spacing: AfterglowShape.line) {
                KickerLabel(text: "Rooms")
                GlassGroup(spacing: AfterglowShape.line) {
                    AfterglowTileGrid(
                        spacing: AfterglowShape.line,
                        minimumColumnWidth: dynamicTypeSize.isAccessibilitySize ? 10_000 : AfterglowShape.cardFloor,
                        maximumColumns: 3
                    ) {
                        ForEach(rooms) { room in
                            RoomTile(
                                title: room.title,
                                detail: room.detail,
                                word: room.word,
                                symbol: room.symbol,
                                tone: room.tone,
                                prominent: room.prominent,
                                samples: room.id == "ad-blocker" ? blockedToday : [],
                                action: openRoom
                            )
                        }
                    }
                }
            }
            VStack(alignment: .leading, spacing: AfterglowShape.line) {
                KickerLabel(text: "Status")
                AfterglowTileGrid(
                    spacing: AfterglowShape.line,
                    minimumColumnWidth: dynamicTypeSize.isAccessibilitySize ? 10_000 : 140,
                    maximumColumns: 3
                ) {
                    StatusChip(title: "All good", tone: .calm)
                    StatusChip(title: "Look", tone: .attention)
                    StatusChip(title: "Down", tone: .problem)
                }
            }
        }
    }

    private var rooms: [GalleryRoom] {
        [
            GalleryRoom(
                id: "ad-blocker",
                title: "Ad blocker",
                detail: "405 blocked today",
                word: "All good",
                symbol: "shield.lefthalf.filled",
                tone: .calm,
                prominent: true
            ),
            GalleryRoom(
                id: "streaming",
                title: "Streaming",
                detail: "Up",
                word: "Up",
                symbol: "play.tv",
                tone: .calm,
                prominent: false
            ),
            GalleryRoom(
                id: "smart-home",
                title: "Smart home",
                detail: "Ready",
                word: "Ready",
                symbol: "homekit",
                tone: .calm,
                prominent: false
            ),
            GalleryRoom(
                id: "remote-help",
                title: "Remote help",
                detail: "Ready",
                word: "Ready",
                symbol: "display.and.arrow.down",
                tone: .calm,
                prominent: false
            ),
            GalleryRoom(
                id: "internet",
                title: "Internet",
                detail: "Address is current",
                word: "Address is current",
                symbol: "globe",
                tone: .calm,
                prominent: false
            ),
            GalleryRoom(
                id: "pi",
                title: "Pi",
                detail: "Up",
                word: "Up",
                symbol: "cpu",
                tone: .calm,
                prominent: false
            ),
            GalleryRoom(
                id: "backups",
                title: "Backups",
                detail: "Last copy Sunday",
                word: "Last copy Sunday",
                symbol: "externaldrive.badge.timemachine",
                tone: .calm,
                prominent: false
            ),
        ]
    }

    private var blockedToday: [Double] {
        [0.32, 0.4, 0.36, 0.52, 0.44, 0.61, 0.5, 0.72, 0.58, 0.8, 0.7, 0.88]
    }

    private func openRoom() {}
}
