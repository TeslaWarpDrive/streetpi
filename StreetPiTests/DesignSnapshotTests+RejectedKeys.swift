import SnapshotTesting
import StreetPiCore
import SwiftUI
import UIKit
@testable import StreetPi

@MainActor
extension DesignSnapshotTests {
    func testRejectedAwayKeyBoard() {
        assertRejectedKey(section: .group(.adBlockerAndDNS))
    }

    func testRejectedAwayKeySettings() {
        assertRejectedKey(section: .settings)
    }

    private func assertRejectedKey(section: AppSection, testName: String = #function) {
        for size in SnapshotScale.allCases {
            for device in SnapshotDevice.allCases {
                let board = AdBlockerHome.offline(now: .streetFixtureNow)
                let view = AppShell(
                    section: section, screen: .explained(board.status, board.snapshot), now: .streetFixtureNow,
                    onSection: { _ in }, desk: board.desk, dnsProblem: .offline, awayStatus: .unreachable,
                    gatewayForm: AwayGatewayForm(address: "https://gateway.example.test", saved: true)
                )
                .modifier(AwayKeyNotice(rejected: true, section: section))
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
                    named: "dark-\(size.rawValue)-\(device.rawValue)", testName: testName
                )
            }
        }
    }
}
