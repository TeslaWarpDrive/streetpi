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
        GeometryReader { proxy in
            let short = proxy.size.height < 640
            ScrollView {
                FitOfferedWidth(maxWidth: wide ? 880 : nil) {
                    column(short: short)
                        .padding(.horizontal, AfterglowShape.page)
                        .padding(.top, compact(short) ? 8 : pageInset)
                        .padding(.bottom, compact(short) ? 8 : pageInset)
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
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
    }

    private func column(short: Bool) -> some View {
        VStack(alignment: .leading, spacing: stackSpacing(short: short)) {
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

    /// Room between tiles on a short phone, so the square grid starts on the first screen.
    private let compactGap: CGFloat = 4

    /// A short phone at the default size keeps the first screen to the mock.
    /// Large text stays on the text styles and uses a tighter gap so the status can wrap.
    private func compact(_ short: Bool) -> Bool {
        short && dynamicTypeSize.isAccessibilitySize == false
    }

    private func stackSpacing(short: Bool) -> CGFloat {
        if dynamicTypeSize.isAccessibilitySize {
            return AfterglowShape.line
        }
        return compact(short) ? compactGap : AfterglowShape.block
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
