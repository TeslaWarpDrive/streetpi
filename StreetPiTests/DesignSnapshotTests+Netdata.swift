import SnapshotTesting
import StreetPiCore
import SwiftUI
import UIKit
import XCTest
@testable import StreetPi

@MainActor
extension DesignSnapshotTests {
    func testAwayNetdataCharts() throws {
        let board = AwayBoard.make(
            latest: try FixtureBook.away(named: "away-live"),
            history: try FixtureBook.away(named: "away-history-netdata")
        )
        let report = try XCTUnwrap(board.snapshot)
        for size in SnapshotScale.allCases {
            for device in SnapshotDevice.allCases {
                let view = AppShell(
                    section: .group(.piHealth), screen: .ready(report), now: .streetFixtureNow,
                    onSection: { _ in }, machine: board.machine, machinePage: .chart,
                    machineReading: report.machine,
                    awayStatus: .reading(generatedAt: report.capturedAt, problem: nil, note: nil)
                )
                .preferredColorScheme(.dark)
                .environment(\.colorScheme, .dark)
                .environment(\.dynamicTypeSize, size.dynamicType)
                .environment(\.streetPiStill, true)
                assertSnapshot(
                    of: view,
                    as: .image(
                        drawHierarchyInKeyWindow: true, precision: 0.96, perceptualPrecision: 0.98,
                        layout: .device(config: device.config),
                        traits: UITraitCollection(traitsFrom: [
                            UITraitCollection(userInterfaceStyle: .dark),
                            UITraitCollection(preferredContentSizeCategory: size.category),
                        ])
                    ).standardRange(),
                    named: "dark-\(size.rawValue)-\(device.rawValue)",
                    testName: "away-netdata-charts"
                )
            }
        }
    }
}
