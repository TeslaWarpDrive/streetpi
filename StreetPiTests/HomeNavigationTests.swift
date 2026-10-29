import StreetPiCore
import SwiftUI
import UIKit
import XCTest
@testable import StreetPi

@MainActor
final class HomeNavigationTests: XCTestCase {
    func testEveryHomePushPopsBackToHouseWithoutSwitchingTabs() throws {
        let destinations = HouseGroup.allCases.map { HomeDestination.room($0) }
            + MachinePage.allCases.map { .machine($0) } + [.devices, .settings]
        for destination in destinations {
            var selections: [AppSection] = []
            let shell = AppShell(
                section: .home, screen: .ready(.healthyFixture), now: .streetFixtureNow,
                onSection: { selections.append($0) },
                statusBoard: StatusPageFixture.previewBoard(), initialHomePath: [destination]
            )
            .preferredColorScheme(.dark)
            .environment(\.horizontalSizeClass, .compact)
            let host = UIHostingController(rootView: shell)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            window.rootViewController = host
            window.makeKeyAndVisible()
            defer { window.isHidden = true; window.rootViewController = nil }
            settle(window)
            let navigation = try XCTUnwrap(navigationController(in: host), "\(destination)")
            XCTAssertEqual(navigation.viewControllers.count, 2, "\(destination) must push a detail")
            XCTAssertFalse(navigation.navigationBar.isHidden, "\(destination) needs a back button")
            XCTAssertNotNil(navigation.popViewController(animated: false))
            settle(window)
            XCTAssertEqual(navigation.viewControllers.count, 1, "\(destination) must return to Home")
            XCTAssertTrue(selections.isEmpty, "\(destination) changed tabs")
        }
    }

    func testRoomContentStaysInsideSmallPhoneAtLargestType() throws {
        for group in [HouseGroup.internet, .backups, .monitors] {
            var frames: [String: CGRect] = [:]
            let shell = AppShell(
                section: .home, screen: .ready(.healthyFixture), now: .streetFixtureNow,
                onSection: { _ in }, statusBoard: StatusPageFixture.previewBoard(), initialRoom: group
            )
            .environment(\.horizontalSizeClass, .compact)
            .environment(\.dynamicTypeSize, .accessibility5)
            .coordinateSpace(name: ClearanceSpace.name)
            .environment(\.streetPiLayoutReport, { name, frame in frames[name] = frame })
            let host = UIHostingController(rootView: shell)
            let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 568))
            window.rootViewController = host
            window.makeKeyAndVisible()
            defer { window.isHidden = true; window.rootViewController = nil }
            settle(window)
            for name in ["room-header", "room-status-list"] {
                let frame = try XCTUnwrap(frames[name], "\(group): missing \(name)")
                XCTAssertGreaterThanOrEqual(frame.minX, 0, "\(group): \(name) spills left")
                XCTAssertLessThanOrEqual(frame.maxX, window.bounds.width, "\(group): \(name) spills right")
            }
        }
    }

    func testNestedPiPageReturnsToPiBeforeHome() throws {
        let shell = AppShell(
            section: .home, screen: .ready(.healthyFixture), now: .streetFixtureNow,
            onSection: { _ in }, initialHomePath: [.room(.piHealth), .machine(.chart)]
        )
        .environment(\.horizontalSizeClass, .compact)
        let host = UIHostingController(rootView: shell)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        settle(window)
        let navigation = try XCTUnwrap(navigationController(in: host))
        XCTAssertEqual(navigation.viewControllers.count, 3)
        XCTAssertNotNil(navigation.popViewController(animated: false))
        settle(window)
        XCTAssertEqual(navigation.viewControllers.count, 2)
        XCTAssertEqual(navigation.navigationBar.topItem?.title, "The Pi")
        XCTAssertNotNil(navigation.popViewController(animated: false))
        settle(window)
        XCTAssertEqual(navigation.viewControllers.count, 1)
    }

    private func settle(_ window: UIWindow) {
        window.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.25))
        window.layoutIfNeeded()
    }

    private func navigationController(in controller: UIViewController) -> UINavigationController? {
        if let navigation = controller as? UINavigationController { return navigation }
        for child in controller.children {
            if let found = navigationController(in: child) { return found }
        }
        return nil
    }
}
