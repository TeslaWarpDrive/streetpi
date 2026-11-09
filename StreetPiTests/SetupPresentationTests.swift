import StreetPiCore
import SwiftUI
import UIKit
import XCTest
@testable import StreetPi

/// The setup form has one owner, the Ad blocker tab. Clients must not present a second sheet.
@MainActor
final class SetupPresentationTests: XCTestCase {
    func testClientsDoesNotPresentTheSetupForm() throws {
        let host = UIHostingController(rootView: clientsShell)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true; window.rootViewController = nil }
        settle(window)

        let navigation = try XCTUnwrap(
            navigationController(titled: "Clients", in: host),
            "Clients should stay on the House stack. Titles: \(titles(in: host))"
        )
        XCTAssertNil(navigation.presentedViewController, "Clients must not present the setup form")
        XCTAssertNil(navigation.topViewController?.presentedViewController)
        XCTAssertFalse(
            contains("Trust this Pi and save the password", in: navigation.topViewController?.view),
            "Clients is showing the setup form"
        )
    }

    private var clientsShell: some View {
        AppShell(
            section: .home,
            screen: .ready(.healthyFixture),
            now: .streetFixtureNow,
            onSection: { _ in },
            passwordSaved: false,
            showsSetup: true,
            dnsProblem: .refused,
            initialHomePath: [.devices]
        )
        .preferredColorScheme(.dark)
        .environment(\.horizontalSizeClass, .compact)
        .environment(\.streetPiStill, true)
    }

    private func settle(_ window: UIWindow) {
        window.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        window.layoutIfNeeded()
    }

    private func titles(in controller: UIViewController) -> [String] {
        var found: [String] = []
        if let navigation = controller as? UINavigationController,
           let title = navigation.navigationBar.topItem?.title {
            found.append(title)
        }
        for child in controller.children {
            found += titles(in: child)
        }
        return found
    }

    private func navigationController(
        titled title: String,
        in controller: UIViewController
    ) -> UINavigationController? {
        if let navigation = controller as? UINavigationController,
           navigation.navigationBar.topItem?.title == title {
            return navigation
        }
        for child in controller.children {
            if let found = navigationController(titled: title, in: child) { return found }
        }
        return nil
    }

    private func contains(_ needle: String, in view: UIView?) -> Bool {
        guard let view else { return false }
        if view.accessibilityLabel?.contains(needle) == true { return true }
        if let label = view as? UILabel, label.text?.contains(needle) == true { return true }
        if let button = view as? UIButton {
            let title = button.currentTitle ?? button.title(for: .normal) ?? button.accessibilityLabel
            if title?.contains(needle) == true { return true }
        }
        return view.subviews.contains { contains(needle, in: $0) }
    }
}
