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
    var onOpenMonitors: () -> Void = {}

    @Environment(\.afterglowPalette) private var palette
    @State private var showMeaning = false

    var body: some View {
        ScrollView {
            FitOfferedWidth(maxWidth: wide ? 880 : nil) {
                column
                    .padding(.horizontal, wide ? AfterglowShape.page : edge)
                    .padding(.top, AfterglowShape.tight)
                    .padding(.bottom, AfterglowShape.block)
            }
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await refresh()
        }
        .sheet(isPresented: $showMeaning) {
            PercentMeaningSheet(title: "About this percent", text: board.blocker.explainer) {
                showMeaning = false
            }
        }
        .containerBackground(palette.ground, for: .navigation)
        .background(palette.ground.ignoresSafeArea())
    }

    private var column: some View {
        VStack(alignment: .leading, spacing: gap) {
            HouseTitleBar(alertCount: alertCount, onAlerts: onAlerts, onSettings: onSettings)
            StatusPill(
                title: board.headline,
                accentWord: HeadlineAccent.word(in: board.headline),
                checkedLine: board.checkedLine,
                tone: board.tone
            )
            .padding(.bottom, AfterglowShape.tight)
            BoardColumns(wide: wide) {
                BlockerCard(
                    tile: board.blocker,
                    onOpen: onOpenBlocker,
                    onHold: onPauseBlocker,
                    onInfo: { showMeaning = true }
                )
                .reportsLayout("home-blocker-card")
            } trailing: {
                PiBoardCard(tile: board.pi) {
                    onOpen(.piHealth)
                }
                .reportsLayout("home-pi-card")
            }
            SquareRow(squares: board.squares, onOpen: onOpen)
            BoardColumns(wide: wide) {
                MonitorBoardCard(tile: board.monitors, onOpen: onOpenMonitors)
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

    /// The phone page edge from the mock. The iPad keeps the wider page margin.
    private let edge: CGFloat = 16

    /// One even gutter between every row, the same as between tiles in a row.
    private var gap: CGFloat {
        wide ? AfterglowShape.line : BoardColumns<EmptyView, EmptyView>.phoneGap
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
