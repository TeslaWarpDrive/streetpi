import SnapshotTesting
import StreetPiCore
import SwiftUI
import UIKit
import XCTest
@testable import StreetPi

@MainActor
final class CertificateFallbackSnapshotTests: XCTestCase {
    func testGatewayCertificatePrompt() {
        assertMatrix(awayLive: true)
    }

    func testMailboxCertificatePrompt() {
        assertMatrix(awayLive: false)
    }

    private func assertMatrix(awayLive: Bool, testName: String = #function) {
        let reading = PiProbe.Reading(
            mode: .offline,
            presentedPin: Data(repeating: 0xFA, count: 32).base64EncodedString()
        )
        for size in SnapshotScale.allCases {
            for device in SnapshotDevice.allCases {
                let view = AppShell(
                    section: .group(.adBlockerAndDNS),
                    screen: .ready(.healthyFixture),
                    now: .streetFixtureNow,
                    onSection: { _ in },
                    dnsProblem: reading.problem(declinedPin: nil),
                    awayStatus: awayLive ? nil : .reading(
                        generatedAt: .streetFixtureNow, problem: nil, note: nil
                    ),
                    awayLive: awayLive
                )
                .preferredColorScheme(.dark)
                .environment(\.colorScheme, .dark)
                .environment(\.dynamicTypeSize, size.dynamicType)
                .environment(\.streetPiStill, true)
                assertSnapshot(
                    of: view,
                    as: .image(
                        drawHierarchyInKeyWindow: true,
                        precision: 0.96,
                        perceptualPrecision: 0.98,
                        layout: .device(config: device.config),
                        traits: UITraitCollection(traitsFrom: [
                            UITraitCollection(userInterfaceStyle: .dark),
                            UITraitCollection(preferredContentSizeCategory: size.category),
                        ])
                    ).standardRange(),
                    named: "dark-\(size.rawValue)-\(device.rawValue)",
                    record: true,
                    testName: testName
                )
            }
        }
    }
}
