import StreetPiCore
import SwiftUI

/// House control center. The tiles read a `ControlBoard`, so a later source can replace the fixture.
struct HouseHome: View {
    var board: ControlBoard
    var alertCount: Int
    var wide: Bool
    var onRefresh: @MainActor () async -> Void
    var onAlerts: () -> Void
    var onSettings: () -> Void
    var onOpen: (HouseGroup) -> Void
    var onOpenBlocker: () -> Void
    var onPauseBlocker: () -> Void
    var onOpenDevices: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var showMeaning = false

    var body: some View {
        ScrollView {
            FitOfferedWidth(maxWidth: wide ? 880 : nil) {
                column
                    .padding(.horizontal, AfterglowShape.page)
                    .padding(.vertical, pageInset)
            }
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await refresh()
        }
        .sheet(isPresented: $showMeaning) {
            PercentMeaningSheet(text: board.blocker.explainer) {
                showMeaning = false
            }
        }
    }

    private var column: some View {
        VStack(alignment: .leading, spacing: AfterglowShape.block) {
            HouseTitleBar(alertCount: alertCount, onAlerts: onAlerts, onSettings: onSettings)
            StatusPill(
                title: board.headline,
                accentWord: HeadlineAccent.word(in: board.headline),
                checkedLine: board.checkedLine
            )
            BoardColumns(wide: wide) {
                BlockerCard(
                    tile: board.blocker,
                    onOpen: onOpenBlocker,
                    onHold: onPauseBlocker,
                    onInfo: { showMeaning = true }
                )
            } trailing: {
                PiBoardCard(tile: board.pi) {
                    onOpen(.piHealth)
                }
            }
            SquareRow(squares: board.squares, onOpen: onOpen)
            BoardColumns(wide: wide) {
                MonitorBoardCard(tile: board.monitors)
            } trailing: {
                BackupBoardCard(tile: board.backups) {
                    onOpen(.backups)
                }
            }
            BoardColumns(wide: wide) {
                RunningBoardCard(tile: board.running) {
                    onOpen(.piHealth)
                }
            } trailing: {
                DevicesBoardCard(tile: board.devices, onOpen: onOpenDevices)
            }
            HouseFooter()
        }
    }

    private var pageInset: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? AfterglowShape.line : AfterglowShape.block
    }

    private func refresh() async {
        await onRefresh()
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
