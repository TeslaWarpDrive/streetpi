import SnapshotTesting
import StreetPiCore
import SwiftUI
import UIKit
import XCTest
@testable import StreetPi

/// The phones the tab-bar checks run on. Both small phones: the SE has a home button
/// and no bottom inset, the 13 mini has a home indicator.
enum ClearancePhone: String, CaseIterable {
    case smallPhone
    case miniPhone
    case largePhone

    var config: ViewImageConfig {
        switch self {
        case .smallPhone: .iPhoneSe
        case .miniPhone: .iPhone13Mini
        case .largePhone: .iPhone13ProMax
        }
    }
}

/// Matches the device safe area instead of borrowing the simulator host phone's insets.
@MainActor
private final class ClearanceWindow: UIWindow {
    var deviceInsets: UIEdgeInsets = .zero

    override var safeAreaInsets: UIEdgeInsets { deviceInsets }
}

private struct ClearanceTab {
    let name: String
    let section: AppSection
}

/// Window walks shared by the clearance tests.
@MainActor
class ClearanceCase: XCTestCase {
    fileprivate let now = Date.streetFixtureNow
    fileprivate let house = HouseholdSnapshot.healthyFixture
    fileprivate var layoutFrames: [String: CGRect] = [:]
    private var layoutSession = UUID()

    fileprivate let tabWords: Set<String> = ["House", "Ad blocker", "Pi", "Settings", "Tab Bar"]
    fileprivate func assertStreamingIsWhole(_ label: UILabel, allowsWrap: Bool) {
        let text = plain(label.text)
        XCTAssertFalse(text.contains("-"), "Streaming is hyphenated: \(text)")
        XCTAssertTrue(text.contains("Streaming"), "Title lost letters: \(text)")
        let font = label.font ?? UIFont.preferredFont(forTextStyle: .subheadline)
        let word = ("Streaming" as NSString).size(withAttributes: [.font: font]).width
        let line = font.lineHeight
        if label.bounds.width + 1 < word {
            XCTAssertTrue(allowsWrap, "Streaming wrapped at the default text size")
            XCTAssertGreaterThan(
                label.bounds.height,
                line * 1.4,
                "Streaming is narrower than the word on one line"
            )
            let needed = label.sizeThatFits(CGSize(width: label.bounds.width, height: 10_000)).height
            XCTAssertGreaterThanOrEqual(label.bounds.height + 1, needed, "Streaming is clipped")
        } else {
            XCTAssertGreaterThanOrEqual(label.bounds.width + 1, word)
        }
    }
    fileprivate func assertFullyDrawn(_ label: UILabel) {
        let needed = label.sizeThatFits(CGSize(width: max(label.bounds.width, 1), height: 10_000))
        XCTAssertGreaterThanOrEqual(
            label.bounds.height + 1,
            needed.height,
            "\(plain(label.text)) is clipped"
        )
    }
    /// Exactly one system tab bar, and none of our own strips.
    fileprivate func assertOneTabBar(in window: UIWindow, _ context: String) {
        let bars = systemTabBars(in: window)
        XCTAssertEqual(bars.count, 1, "\(context): expected one tab bar, saw \(bars.count)")
        XCTAssertTrue(
            views(named: "phone-tab-strip", in: window).isEmpty,
            "\(context): a second tab strip is on screen"
        )
    }
    /// The actual final Text must be fully visible after scrolling to the end.
    fileprivate func assertPageEnd(in window: UIWindow, _ context: String) {
        guard let bar = tabBarFrame(in: window) else {
            XCTFail("\(context): no tab bar")
            return
        }
        guard let last = layoutFrames["page-end"], last.isNull == false, last.isInfinite == false else {
            XCTFail("\(context): the final row did not report its layout")
            return
        }
        let area = pageArea(in: window).intersection(window.bounds)
        let limit = min(area.maxY, bar.minY)
        XCTAssertGreaterThan(last.height, 1, "\(context): final row has no height")
        XCTAssertGreaterThan(last.width, 1, "\(context): final row has no width")
        // A text frame includes leading above the first glyph. On the small phone
        // at the largest size, that leading can sit a few points above the screen
        // while the words stay fully drawn and the line still ends above the bar.
        let frameLeading: CGFloat = 8
        XCTAssertGreaterThanOrEqual(
            last.minY,
            area.minY - frameLeading,
            "\(context): final row starts off screen. row=\(last) area=\(area) bar=\(bar)"
        )
        XCTAssertLessThanOrEqual(
            last.maxY,
            limit + 0.5,
            "\(context): final row ends under the tab bar. row=\(last) area=\(area) bar=\(bar)"
        )
        XCTAssertGreaterThanOrEqual(last.minX, area.minX - 0.5, "\(context): final row starts outside page")
        XCTAssertLessThanOrEqual(last.maxX, area.maxX + 0.5, "\(context): final row ends outside page")
    }
    fileprivate func assertVisibleTextDoesNotOverlap(in window: UIWindow, _ context: String) {
        let area = pageArea(in: window)
        var leaves: [(text: String, frame: CGRect)] = []
        for item in pageTexts(in: window) {
            let shown = item.frame.intersection(area)
            let leaf = shown.width > 2 && shown.height > 2 && shown.height < 72
            let narrow = shown.width < window.bounds.width * 0.92
            guard leaf, narrow else { continue }
            leaves.append((item.text, shown))
        }
        for index in leaves.indices {
            for other in leaves.indices.dropFirst(index + 1) {
                let left = leaves[index]
                let right = leaves[other]
                if covers(left.frame, right.frame) || covers(right.frame, left.frame) { continue }
                let overlap = left.frame.intersection(right.frame)
                guard overlap.width > 3, overlap.height > 3 else { continue }
                XCTFail("\(context): \(left.text) overlaps \(right.text)")
            }
        }
    }
    fileprivate func covers(_ outer: CGRect, _ inner: CGRect) -> Bool {
        outer.insetBy(dx: -2, dy: -2).contains(inner)
    }
    /// The part of the window the page draws into. It includes the strip behind the tab bar,
    /// so text that slid under the bar still counts.
    fileprivate func pageArea(in window: UIWindow) -> CGRect {
        guard let scroll = mainScroll(in: window) else { return window.bounds }
        return scroll.convert(scroll.bounds, to: window).intersection(window.bounds)
    }
    fileprivate func label(_ identifier: String, in window: UIWindow) -> UILabel? {
        labels(in: window).first {
            $0.accessibilityIdentifier == identifier && $0.bounds.width > 2 && $0.bounds.height > 2
        }
    }
    fileprivate func host(
        page: AppSection,
        scale: SnapshotScale,
        config: ViewImageConfig,
        status: HouseStatusBoard? = nil,
        snapshot: HouseholdSnapshot? = nil
    ) -> UIWindow {
        layoutFrames.removeAll()
        let session = UUID()
        layoutSession = session
        let root = AppShell(
            section: page,
            screen: .ready(snapshot ?? house),
            now: now,
            onSection: { _ in },
            statusBoard: status
        )
        .preferredColorScheme(.dark)
        .environment(\.colorScheme, .dark)
        .environment(\.dynamicTypeSize, scale.dynamicType)
        .environment(\.streetPiStill, true)
        .coordinateSpace(name: ClearanceSpace.name)
        .environment(\.streetPiLayoutReport, { [weak self] name, frame in
            guard let self, self.layoutSession == session else { return }
            self.layoutFrames[name] = frame
        })
        let controller = UIHostingController(rootView: root)
        controller.overrideUserInterfaceStyle = .dark
        let traits = UITraitCollection(traitsFrom: [
            config.traits,
            UITraitCollection(userInterfaceStyle: .dark),
            UITraitCollection(preferredContentSizeCategory: scale.category),
        ])
        let frame = CGRect(origin: .zero, size: config.size ?? CGSize(width: 375, height: 667))
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map { ClearanceWindow(windowScene: $0) } ?? ClearanceWindow(frame: frame)
        window.deviceInsets = config.safeArea
        window.frame = frame
        let container = UIViewController()
        container.view.frame = frame
        container.addChild(controller)
        container.setOverrideTraitCollection(traits, forChild: controller)
        controller.view.frame = container.view.bounds
        controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.view.addSubview(controller.view)
        controller.didMove(toParent: container)
        window.rootViewController = container
        window.overrideUserInterfaceStyle = .dark
        window.makeKeyAndVisible()
        container.beginAppearanceTransition(true, animated: false)
        container.endAppearanceTransition()
        container.view.setNeedsLayout()
        container.view.layoutIfNeeded()
        pump()
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        pump()
        return window
    }

}

@MainActor
extension ClearanceCase {
    fileprivate func streamingLabel(in window: UIWindow) -> UILabel? {
        labels(in: window).first { plain($0.text).contains("Streaming") }
    }
    fileprivate func labelTexts(in window: UIWindow) -> [String] {
        labels(in: window).map { plain($0.text) }.filter { $0.isEmpty == false }
    }
    fileprivate func labels(in view: UIView) -> [UILabel] {
        var found: [UILabel] = []
        if let label = view as? UILabel {
            found.append(label)
        }
        for child in view.subviews {
            found.append(contentsOf: labels(in: child))
        }
        return found
    }
    fileprivate func scrollToEnd(_ window: UIWindow) {
        guard let scroll = mainScroll(in: window) else { return }
        let bottom = scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom
        scroll.setContentOffset(CGPoint(x: 0, y: max(-scroll.adjustedContentInset.top, bottom)), animated: false)
        scroll.layoutIfNeeded()
        pump()
    }
    /// Scrolls the page the way a person would until the frame is fully above the bar.
    fileprivate func scrollIntoView(_ view: UIView, in window: UIWindow) {
        guard let scroll = mainScroll(in: window) else { return }
        let rect = view.convert(view.bounds, to: scroll).insetBy(dx: 0, dy: -8)
        scroll.scrollRectToVisible(rect, animated: false)
        scroll.layoutIfNeeded()
        pump()
    }
    fileprivate func mainScroll(in window: UIWindow) -> UIScrollView? {
        allScrolls(in: window)
            .filter { $0.bounds.height > window.bounds.height * 0.4 }
            .max { $0.bounds.width * $0.bounds.height < $1.bounds.width * $1.bounds.height }
    }
    fileprivate func tabBarFrame(in window: UIWindow) -> CGRect? {
        guard let bar = systemTabBars(in: window).first else { return nil }
        return bar.convert(bar.bounds, to: window)
    }
    fileprivate func systemTabBars(in view: UIView) -> [UITabBar] {
        let shown = view.isHidden == false && view.alpha > 0.01 && view.bounds.height > 1
        guard shown else { return [] }
        if let bar = view as? UITabBar {
            return [bar]
        }
        return view.subviews.flatMap { systemTabBars(in: $0) }
    }
    fileprivate func views(named name: String, in view: UIView) -> [UIView] {
        var found: [UIView] = []
        if view.accessibilityIdentifier == name {
            found.append(view)
        }
        for child in view.subviews {
            found.append(contentsOf: views(named: name, in: child))
        }
        return found
    }
    /// Text and spoken labels on the page, not in the tab bar, and not whole-screen containers.
    fileprivate func pageTexts(in window: UIWindow) -> [(text: String, frame: CGRect)] {
        textFrames(in: window).filter { item in
            tabWords.contains(item.text) == false
                && item.frame.height < window.bounds.height * 0.6
                && item.frame.width > 1
        }
    }
    fileprivate func textFrames(in window: UIWindow) -> [(text: String, frame: CGRect)] {
        var found: [(text: String, frame: CGRect)] = []
        var visited = Set<ObjectIdentifier>()
        collectText(in: window, window: window, visited: &visited, into: &found)
        return found
    }
    /// SwiftUI creates virtual accessibility children lazily; UILabel walks miss native Text.
    fileprivate func collectText(
        in object: NSObject,
        window: UIWindow,
        visited: inout Set<ObjectIdentifier>,
        into found: inout [(text: String, frame: CGRect)]
    ) {
        guard visited.insert(ObjectIdentifier(object)).inserted else { return }
        if let view = object as? UIView {
            if view is UITabBar || view.isHidden || view.alpha < 0.01 { return }
            if let label = view as? UILabel, plain(label.text).isEmpty == false {
                found.append((plain(label.text), label.convert(label.bounds, to: window)))
            }
        }
        let spoken = plain(object.accessibilityLabel)
        if spoken.isEmpty == false {
            let frame: CGRect
            if let view = object as? UIView {
                frame = view.convert(view.bounds, to: window)
            } else {
                frame = window.convert(object.accessibilityFrame, from: nil)
            }
            found.append((spoken, frame))
        }
        let count = object.accessibilityElementCount()
        if count > 0 && count < 10_000 {
            for index in 0..<count {
                if let element = object.accessibilityElement(at: index) as? NSObject {
                    collectText(in: element, window: window, visited: &visited, into: &found)
                }
            }
        }
        if let view = object as? UIView {
            for child in view.subviews {
                collectText(in: child, window: window, visited: &visited, into: &found)
            }
        }
    }
    fileprivate func plain(_ text: String?) -> String {
        (text ?? "").replacingOccurrences(of: "\u{2060}", with: "")
    }
    fileprivate func pump() {
        for _ in 0..<6 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.02))
        }
    }
    fileprivate func allScrolls(in view: UIView) -> [UIScrollView] {
        var found: [UIScrollView] = []
        if let scroll = view as? UIScrollView {
            found.append(scroll)
        }
        for child in view.subviews {
            found.append(contentsOf: allScrolls(in: child))
        }
        return found
    }
    fileprivate func image(of window: UIWindow) -> UIImage {
        guard let view = window.rootViewController?.view else {
            XCTFail("The snapshot window has no root view")
            return UIImage()
        }
        let renderer = UIGraphicsImageRenderer(bounds: view.bounds)
        return renderer.image { _ in
            view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }
    }
}

/// Fails when a tab's last row ends under the tab bar, when a second bar appears,
/// or when two pieces of text overlap.
@MainActor
final class TabClearanceTests: ClearanceCase {
    private let tabs: [ClearanceTab] = [
        ClearanceTab(name: "house", section: .home),
        ClearanceTab(name: "ad-blocker", section: .group(.adBlockerAndDNS)),
        ClearanceTab(name: "pi", section: .group(.piHealth)),
        ClearanceTab(name: "settings", section: .settings),
    ]
    /// Every tab, scrolled to its end, on the small phones and a large one at both text sizes.
    /// Each end state is also kept as an image, so the last row can be looked at.
    func testEveryTabEndsAboveTheTabBar() {
        for phone in ClearancePhone.allCases {
            for scale in SnapshotScale.allCases {
                for tab in tabs {
                    let context = "\(tab.name) \(scale.rawValue) \(phone.rawValue)"
                    let window = host(page: tab.section, scale: scale, config: phone.config)
                    assertOneTabBar(in: window, context)
                    assertVisibleTextDoesNotOverlap(in: window, context)
                    scrollToEnd(window)
                    assertPageEnd(in: window, context)
                    assertVisibleTextDoesNotOverlap(in: window, context)
                    assertSnapshot(
                        of: image(of: window),
                        as: .image(precision: 0.99, perceptualPrecision: 0.98).standardRange(),
                        named: "\(tab.name)-dark-\(scale.rawValue)-\(phone.rawValue)",
                        testName: "tabEnd"
                    )
                    window.isHidden = true
                }
            }
        }
    }
    /// The iPad opens on the sidebar. No tab bar sits along the bottom of the page.
    func testPadHasNoBottomBar() {
        for scale in SnapshotScale.allCases {
            let window = host(page: .home, scale: scale, config: SnapshotDevice.pad.config)
            XCTAssertTrue(systemTabBars(in: window).isEmpty, "The iPad must open on a sidebar")
            let splits = window.rootViewController.map { splitControllers(in: $0) } ?? []
            XCTAssertEqual(splits.count, 1, "The iPad needs exactly one navigation split view")
            XCTAssertEqual(splits.first?.isCollapsed, false, "The iPad sidebar must be expanded")
            window.isHidden = true
        }
    }

    private func splitControllers(in controller: UIViewController) -> [UISplitViewController] {
        let own = (controller as? UISplitViewController).map { [$0] } ?? []
        return own + controller.children.flatMap { splitControllers(in: $0) }
    }
    func testStreamingTitleStaysWhole() {
        for scale in SnapshotScale.allCases {
            let window = host(page: .home, scale: scale, config: ClearancePhone.smallPhone.config)
            guard let label = streamingLabel(in: window) else {
                XCTFail("Streaming is not in the view. Saw: \(labelTexts(in: window).joined(separator: " | "))")
                window.isHidden = true
                continue
            }
            scrollIntoView(label, in: window)
            assertStreamingIsWhole(label, allowsWrap: scale == .largest)
            if let bar = tabBarFrame(in: window) {
                let frame = label.convert(label.bounds, to: window)
                XCTAssertLessThanOrEqual(frame.maxY, bar.minY + 0.5, "Streaming is not above the tab bar")
            } else {
                XCTFail("No tab bar")
            }
            window.isHidden = true
        }
    }
    /// The status word and the checked line stay apart, and the checked line is fully drawn.
    func testStatusWordClearsTheCheckedLine() {
        let configs: [(String, ViewImageConfig)] = [
            ("smallPhone", ClearancePhone.smallPhone.config),
            ("largePhone", ClearancePhone.largePhone.config),
            ("pad", SnapshotDevice.pad.config),
        ]
        for (name, config) in configs {
            for scale in SnapshotScale.allCases {
                let context = "\(name) \(scale.rawValue)"
                let window = host(page: .home, scale: scale, config: config)
                guard let checked = label("checked-line", in: window) else {
                    XCTFail("\(context): the checked line is missing")
                    window.isHidden = true
                    continue
                }
                XCTAssertTrue(plain(checked.text).contains("just now"), "Checked line lost its words")
                assertFullyDrawn(checked)
                let checkedFrame = checked.convert(checked.bounds, to: window)
                if let status = layoutFrames["status-word"] {
                    XCTAssertGreaterThan(status.width, 1, "\(context): the status word has no width")
                    XCTAssertGreaterThan(status.height, 1, "\(context): the status word has no height")
                    let overlap = status.intersection(checkedFrame)
                    XCTAssertTrue(
                        overlap.isNull || overlap.width < 1 || overlap.height < 1,
                        "\(context): the status word overlaps the checked line"
                    )
                } else {
                    XCTFail("\(context): the status word is missing")
                }
                if let plainLine = label("blocker-plain", in: window) {
                    assertFullyDrawn(plainLine)
                } else {
                    XCTFail("\(context): the ad blocker line is missing")
                }
                window.isHidden = true
            }
        }
    }
    /// The fixture Home paints the monitor count, not the sample backup sentence.
    func testSamplePhrasesStayOffTheHomeCards() {
        let window = host(page: .home, scale: .default, config: ClearancePhone.smallPhone.config)
        let spoken = textFrames(in: window).map(\.text).joined(separator: " ")
        XCTAssertTrue(spoken.contains("8 of 8 up"), spoken)
        XCTAssertFalse(spoken.contains("The weekly copy succeeded."), spoken)
        XCTAssertFalse(spoken.contains("All answering"), spoken)
        XCTAssertTrue(spoken.contains("About 1 in 5 things"), spoken)
        XCTAssertTrue(spoken.contains("using the Pi"), spoken)
        window.isHidden = true
    }

    func testPadHomeCardsFitWithTheSidebarOpen() {
        for device in [SnapshotDevice.pad, .padLandscape] {
            for scale in SnapshotScale.allCases {
                let window = host(page: .home, scale: scale, config: device.config)
                for name in ["home-blocker-card", "home-pi-card"] {
                    guard let frame = layoutFrames[name] else {
                        XCTFail("\(device) \(scale): \(name) did not report its layout")
                        continue
                    }
                    XCTAssertGreaterThan(frame.width, 1)
                    XCTAssertGreaterThanOrEqual(frame.minX, window.bounds.minX - 0.5,
                                                "\(device) \(scale): \(name) starts outside the window")
                    XCTAssertLessThanOrEqual(frame.maxX, window.bounds.maxX + 0.5,
                                             "\(device) \(scale): \(name) extends past the window")
                }
                window.isHidden = true
            }
        }
    }
    /// The installed Home paints the status page, not the 8-service sample.
    func testStatusPageReplacesTheSample() {
        let board = StatusPageFixture.previewBoard(now: now)
        let window = host(
            page: .home,
            scale: .default,
            config: SnapshotDevice.pad.config,
            status: board,
            snapshot: StatusPageFixture.previewSnapshot(now: now)
        )
        let spoken = textFrames(in: window).map(\.text).joined(separator: " ")
        XCTAssertFalse(spoken.contains("8 of 8"))
        XCTAssertFalse(spoken.contains("The weekly copy succeeded."))
        XCTAssertTrue(spoken.contains("27 of 28"), spoken)
        XCTAssertTrue(spoken.contains("check-in"), spoken)
        XCTAssertTrue(spoken.contains("up to date"), spoken)
        window.isHidden = true
    }
}
