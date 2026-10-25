import StreetPiCore
import SwiftUI

/// Control-center Home. The board is the only content the view reads.
struct HouseHome: View {
    var board: HomeBoard
    var alertCount: Int
    var wide: Bool
    var onRefresh: @MainActor () async -> Void
    var onAlerts: () -> Void
    var onSettings: () -> Void
    var onOpenAdBlocker: () -> Void
    var onHoldAdBlocker: () -> Void
    var onOpen: (HouseGroup) -> Void
    var onOpenDevices: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AfterglowShape.block) {
                header
                HomeStatusRow(board: board)
                hero
                services
                monitorsAndBackups
                facts
                Text(board.footer)
                    .font(.footnote)
                    .foregroundStyle(palette.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, AfterglowShape.page)
            .padding(.vertical, dynamicTypeSize.isAccessibilitySize ? AfterglowShape.tight : AfterglowShape.block)
            .frame(maxWidth: wide ? 980 : 560)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .refreshable {
            await onRefresh()
        }
    }

    @Environment(\.afterglowPalette) private var palette

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: AfterglowShape.line) {
                title
                Spacer(minLength: AfterglowShape.line)
                chrome
            }
            VStack(alignment: .leading, spacing: AfterglowShape.line) {
                title
                chrome
            }
        }
    }

    private var title: some View {
        Text(board.title)
            .font(dynamicTypeSize.isAccessibilitySize ? .title.bold() : .largeTitle.bold())
            .foregroundStyle(palette.ink)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }

    private var chrome: some View {
        ChromeButtonPair(
            first: AlertsBell(alertCount: alertCount, action: onAlerts),
            second: IconChromeButton(title: "Settings", systemImage: "gearshape", action: onSettings)
        )
    }

    private var hero: some View {
        AfterglowTileGrid(
            spacing: AfterglowShape.line,
            minimumColumnWidth: dynamicTypeSize.isAccessibilitySize ? 10_000 : 168,
            maximumColumns: dynamicTypeSize.isAccessibilitySize ? 1 : 2
        ) {
            AdBlockerHomeCard(
                reading: board.adBlocker,
                onOpen: onOpenAdBlocker,
                onHold: onHoldAdBlocker
            )
            PiHomeTile(reading: board.pi) {
                onOpen(.piHealth)
            }
        }
    }

    private var services: some View {
        AfterglowTileGrid(
            spacing: AfterglowShape.line,
            minimumColumnWidth: dynamicTypeSize.isAccessibilitySize ? 10_000 : 132,
            maximumColumns: serviceColumns
        ) {
            ForEach(board.services) { square in
                HomeServiceSquareView(square: square) {
                    onOpen(square.group)
                }
            }
        }
    }

    private var serviceColumns: Int {
        if dynamicTypeSize.isAccessibilitySize {
            return 1
        }
        return wide ? 4 : 2
    }

    private var monitorsAndBackups: some View {
        AfterglowTileGrid(
            spacing: AfterglowShape.line,
            minimumColumnWidth: dynamicTypeSize.isAccessibilitySize || wide == false ? 10_000 : 280,
            maximumColumns: dynamicTypeSize.isAccessibilitySize || wide == false ? 1 : 2
        ) {
            HomeMonitorBoardView(board: board.monitors, onOpen: onOpen)
            HomeFactCard(
                title: board.backups.title,
                value: board.backups.value,
                line: board.backups.line,
                spoken: board.backups.spoken
            ) {
                onOpen(board.backups.group)
            }
        }
    }

    private var facts: some View {
        AfterglowTileGrid(
            spacing: AfterglowShape.line,
            minimumColumnWidth: dynamicTypeSize.isAccessibilitySize ? 10_000 : 160,
            maximumColumns: dynamicTypeSize.isAccessibilitySize ? 1 : 2
        ) {
            HomeFactCard(
                title: board.uptime.title,
                value: board.uptime.value,
                line: board.uptime.line,
                spoken: board.uptime.spoken
            ) {
                onOpen(.piHealth)
            }
            HomeFactCard(
                title: board.devices.title,
                value: board.devices.value,
                line: board.devices.line,
                spoken: board.devices.spoken,
                action: onOpenDevices
            )
        }
    }
}
