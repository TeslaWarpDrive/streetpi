import SnapshotTesting
import StreetPiCore
import SwiftUI
import UIKit
import XCTest
@testable import StreetPi

/// Window walks shared by the clearance tests.
@MainActor
class ClearanceCase: XCTestCase {
    fileprivate let now = Date.streetFixtureNow
    fileprivate let house = HouseholdSnapshot.healthyFixture

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

    fileprivate func assertCheckedLineIsWhole(in window: UIWindow) {
        let label = requireLabel("checked-line", in: window)
        XCTAssertTrue(plain(label.text).contains("just now"), "Checked line lost its words: \(plain(label.text))")
        assertFullyDrawn(label)
        let frame = label.convert(label.bounds, to: window)
        XCTAssertTrue(clearsEveryBar(frame, in: window), "Checked just now sits under the tab bar")
    }

    fileprivate func assertAccentClearsCheckedLine(in window: UIWindow) {
        guard let accent = find("status-accent", in: window),
              let checked = label("checked-line", in: window) else {
            XCTFail("The status word or the checked line is missing")
            return
        }
        let accentFrame = accent.convert(accent.bounds, to: window)
        let checkedFrame = checked.convert(checked.bounds, to: window)
        let overlap = accentFrame.intersection(checkedFrame)
        XCTAssertTrue(
            overlap.isNull || overlap.width < 1 || overlap.height < 1,
            "The status word overlaps the checked line"
        )
    }

    fileprivate func assertFullyDrawn(_ label: UILabel) {
        let needed = label.sizeThatFits(CGSize(width: max(label.bounds.width, 1), height: 10_000))
        XCTAssertGreaterThanOrEqual(
            label.bounds.height + 1,
            needed.height,
            "\(plain(label.text)) is clipped"
        )
    }

    fileprivate func assertVisibleTextClearsBar(in window: UIWindow) {
        XCTAssertTrue(systemTabBars(in: window).isEmpty, "The system tab bar is still on screen")
        let texts = textFrames(in: window)
        XCTAssertFalse(texts.isEmpty, "No text was found to compare with the tab bar")
        let visible = visiblePage(in: window)
        let tabWords: Set<String> = ["House", "Ad blocker", "Pi", "Settings", "Tabs"]
        for item in texts where tabWords.contains(item.text) == false {
            let shown = item.frame.intersection(visible)
            let coversWindow = shown.height > window.bounds.height * 0.9
                && shown.width > window.bounds.width * 0.9
            guard shown.height > 1, coversWindow == false else { continue }
            XCTAssertTrue(
                clearsEveryBar(shown, in: window),
                "\(item.text) sits under the tab bar"
            )
        }
    }

    fileprivate func assertVisibleTextDoesNotOverlap(in window: UIWindow) {
        let visible = visiblePage(in: window)
        let tabWords: Set<String> = ["House", "Ad blocker", "Pi", "Settings"]
        var leaves: [(text: String, frame: CGRect)] = []
        for item in textFrames(in: window) where tabWords.contains(item.text) == false {
            let shown = item.frame.intersection(visible)
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
                XCTFail("\(left.text) overlaps \(right.text)")
            }
        }
    }

    fileprivate func covers(_ outer: CGRect, _ inner: CGRect) -> Bool {
        outer.insetBy(dx: -2, dy: -2).contains(inner)
    }

    fileprivate func clears(_ frame: CGRect, bar: CGRect, in window: UIWindow) -> Bool {
        let shown = frame.intersection(visiblePage(in: window))
        guard shown.height > 1 else { return false }
        let overlap = shown.intersection(bar)
        return overlap.isNull || overlap.height < 1
    }

    /// A line that is still below the fold is not under the bar. The part on screen must clear it.
    fileprivate func visibleClears(_ frame: CGRect, bar: CGRect, in window: UIWindow) -> Bool {
        let shown = frame.intersection(visiblePage(in: window))
        guard shown.height > 1 else { return true }
        let overlap = shown.intersection(bar)
        return overlap.isNull || overlap.height < 1
    }

    fileprivate func visiblePage(in window: UIWindow) -> CGRect {
        guard let scroll = mainScroll(in: window) else { return window.bounds }
        let inset = scroll.bounds.inset(by: scroll.adjustedContentInset)
        return scroll.convert(inset, to: window)
    }

    fileprivate func requireLabel(_ identifier: String, in window: UIWindow) -> UILabel {
        guard let label = label(identifier, in: window) else {
            XCTFail("\(identifier) is not in the view. Saw: \(labelTexts(in: window).joined(separator: " | "))")
            return UILabel()
        }
        return label
    }

    fileprivate func label(_ identifier: String, in window: UIWindow) -> UILabel? {
        labels(in: window).first {
            $0.accessibilityIdentifier == identifier && $0.bounds.width > 2 && $0.bounds.height > 2
        }
    }

    fileprivate func find(_ name: String, in view: UIView) -> UIView? {
        if view.accessibilityIdentifier == name, view.bounds.width > 2, view.bounds.height > 2 {
            return view
        }
        for child in view.subviews {
            if let found = find(name, in: child) { return found }
        }
        return nil
    }

    fileprivate func host(
        page: AppSection,
        scale: SnapshotScale,
        device: SnapshotDevice,
        pinStreaming: Bool = false,
        status: HouseStatusBoard? = nil,
        snapshot: HouseholdSnapshot? = nil,
        dnsPage: DNSPage? = nil
    ) -> UIWindow {
        let root = AppShell(
            section: page,
            screen: .ready(snapshot ?? house),
            now: now,
            onSection: { _ in },
            dnsPage: dnsPage,
            statusBoard: status
        )
        .preferredColorScheme(.dark)
        .environment(\.colorScheme, .dark)
        .environment(\.dynamicTypeSize, scale.dynamicType)
        .environment(\.streetPiStill, true)
        .environment(\.pinsStreamingTitle, pinStreaming)
        let controller = UIHostingController(rootView: root)
        controller.overrideUserInterfaceStyle = .dark
        controller.traitOverrides.preferredContentSizeCategory = scale.category
        controller.traitOverrides.userInterfaceStyle = .dark
        let size = device.config.size ?? CGSize(width: 320, height: 568)
        controller.view.bounds = CGRect(origin: .zero, size: size)
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.overrideUserInterfaceStyle = .dark
        window.makeKeyAndVisible()
        pump()
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        pump()
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        pump()
        return window
    }

    fileprivate func assertFullyInside(_ label: UILabel, in window: UIWindow, name: String) {
        let frame = label.convert(label.bounds, to: window)
        let visible = visiblePage(in: window).insetBy(dx: -1, dy: -1)
        XCTAssertTrue(visible.contains(frame), "\(name) is off the screen")
        XCTAssertTrue(clearsEveryBar(frame, in: window), "\(name) sits under the tab bar")
    }

    fileprivate func visibleClearsEvery(_ frame: CGRect, in window: UIWindow) -> Bool {
        bars(in: window).allSatisfy { visibleClears(frame, bar: $0, in: window) }
    }

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
        scroll.setContentOffset(CGPoint(x: 0, y: max(0, bottom)), animated: false)
        scroll.layoutIfNeeded()
        pump()
    }

    fileprivate func mainScroll(in window: UIWindow) -> UIScrollView? {
        allScrolls(in: window)
            .filter { $0.contentSize.height > $0.bounds.height + 20 }
            .max { $0.contentSize.height < $1.contentSize.height }
    }

    fileprivate func clearsEveryBar(_ frame: CGRect, in window: UIWindow) -> Bool {
        bars(in: window).allSatisfy { clears(frame, bar: $0, in: window) }
    }

    fileprivate func bars(in window: UIWindow) -> [CGRect] {
        var frames = views(named: "phone-tab-strip", in: window).map {
            $0.convert($0.bounds, to: window)
        }
        frames.append(contentsOf: systemTabBars(in: window).map {
            $0.convert($0.bounds, to: window)
        })
        let usable = frames.filter { frame in
            frame.width > 1 && frame.height > 1 && frame.height < window.bounds.height * 0.8
        }
        if usable.isEmpty == false {
            return usable
        }
        let reservedHeight = min(TabClearance.phoneBar, window.bounds.height)
        return [
            CGRect(
                x: 0,
                y: window.bounds.height - reservedHeight,
                width: window.bounds.width,
                height: reservedHeight
            ),
        ]
    }

    fileprivate func systemTabBars(in view: UIView) -> [UIView] {
        var found: [UIView] = []
        let shown = view.isHidden == false && view.alpha > 0.01 && view.bounds.height > 1 && view.bounds.width > 1
        if view is UITabBar, shown {
            found.append(view)
        }
        for child in view.subviews {
            found.append(contentsOf: systemTabBars(in: child))
        }
        return found
    }

    fileprivate func tabBarFrame(in window: UIWindow) -> CGRect {
        let widest = bars(in: window).max { $0.width * $0.height < $1.width * $1.height }
        if let widest {
            return widest
        }
        let height = min(TabClearance.phoneBar, window.bounds.height)
        return CGRect(x: 0, y: window.bounds.height - height, width: window.bounds.width, height: height)
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

    fileprivate func textFrames(in window: UIWindow) -> [(text: String, frame: CGRect)] {
        var found: [(text: String, frame: CGRect)] = []
        collectText(in: window, window: window, into: &found)
        return found
    }

    fileprivate func collectText(in view: UIView, window: UIWindow, into found: inout [(text: String, frame: CGRect)]) {
        if let label = view as? UILabel {
            let text = plain(label.text)
            if text.isEmpty == false {
                found.append((text, label.convert(label.bounds, to: window)))
            }
        }
        let spoken = plain(view.accessibilityLabel)
        if spoken.isEmpty == false {
            found.append((spoken, view.convert(view.bounds, to: window)))
        }
        if let elements = view.accessibilityElements {
            for case let element as NSObject in elements {
                let text = plain(element.accessibilityLabel)
                if text.isEmpty { continue }
                let frame = window.convert(element.accessibilityFrame, from: nil)
                found.append((text, frame))
            }
        }
        for child in view.subviews {
            collectText(in: child, window: window, into: &found)
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
}

/// Fails when type sits under the tab bar, or when two pieces of text overlap.
@MainActor
final class TabClearanceTests: ClearanceCase {
    func testVisibleTextClearsTheTabBar() {
        let pages: [(AppSection, DNSPage?)] = [
            (.home, nil),
            (.group(.adBlockerAndDNS), nil),
            (.group(.adBlockerAndDNS), .today),
            (.group(.piHealth), nil),
            (.settings, nil),
        ]
        for device in [SnapshotDevice.smallPhone, .largePhone] {
            for scale in SnapshotScale.allCases {
                for page in pages {
                    let window = host(page: page.0, scale: scale, device: device, dnsPage: page.1)
                    assertVisibleTextClearsBar(in: window)
                    assertVisibleTextDoesNotOverlap(in: window)
                    scrollToEnd(window)
                    assertVisibleTextClearsBar(in: window)
                    assertVisibleTextDoesNotOverlap(in: window)
                    window.isHidden = true
                }
            }
        }
    }

    func testStreamingTitleStaysWhole() {
        for scale in SnapshotScale.allCases {
            let window = host(page: .home, scale: scale, device: .smallPhone, pinStreaming: true)
            guard let label = streamingLabel(in: window) else {
                XCTFail("Streaming is not in the view. Saw: \(labelTexts(in: window).joined(separator: " | "))")
                window.isHidden = true
                continue
            }
            assertStreamingIsWhole(label, allowsWrap: scale == .largest)
            assertVisibleTextClearsBar(in: window)
            assertVisibleTextDoesNotOverlap(in: window)
            assertFullyInside(label, in: window, name: "Streaming")
            window.isHidden = true
        }
    }

    /// The status word and the checked line stay apart, and the checked line is fully drawn.
    func testStatusWordClearsTheCheckedLine() {
        let devices: [SnapshotDevice] = [.smallPhone, .largePhone, .pad]
        for device in devices {
            for scale in SnapshotScale.allCases {
                let window = host(page: .home, scale: scale, device: device)
                assertCheckedLineIsWhole(in: window)
                assertAccentClearsCheckedLine(in: window)
                if device != .pad {
                    assertVisibleTextClearsBar(in: window)
                    let plain = requireLabel("blocker-plain", in: window)
                    assertFullyDrawn(plain)
                    let frame = plain.convert(plain.bounds, to: window)
                    XCTAssertTrue(
                        visibleClearsEvery(frame, in: window),
                        "The ad blocker line sits under the tab bar"
                    )
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
            device: .pad,
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

    /// The small-phone proof shows the checked line, the ad blocker sentence, and Streaming above the bar.
    func testHomeProofStaysAboveTheTabBar() {
        for scale in SnapshotScale.allCases {
            let window = host(page: .home, scale: scale, device: .smallPhone, pinStreaming: true)
            assertVisibleTextClearsBar(in: window)
            assertVisibleTextDoesNotOverlap(in: window)
            assertAccentClearsCheckedLine(in: window)
            let checked = requireLabel("checked-line", in: window)
            assertFullyDrawn(checked)
            assertFullyInside(checked, in: window, name: "Checked just now")
            let plain = requireLabel("blocker-plain", in: window)
            assertFullyDrawn(plain)
            assertFullyInside(plain, in: window, name: "The ad blocker line")
            guard let streaming = streamingLabel(in: window) else {
                XCTFail("Streaming is off the screen. Saw: \(labelTexts(in: window).joined(separator: " | "))")
                window.isHidden = true
                continue
            }
            assertStreamingIsWhole(streaming, allowsWrap: scale == .largest)
            assertFullyInside(streaming, in: window, name: "Streaming")
            window.isHidden = true
        }
    }

    /// Small-phone shots at both text sizes. Recording is on until the new references land.
    func testHomeClearProof() {
        for scale in SnapshotScale.allCases {
            let view = AppShell(
                section: .home,
                screen: .ready(house),
                now: now,
                onSection: { _ in }
            )
            .preferredColorScheme(.dark)
            .environment(\.colorScheme, .dark)
            .environment(\.dynamicTypeSize, scale.dynamicType)
            .environment(\.streetPiStill, true)
            .environment(\.pinsStreamingTitle, true)
            let traits = UITraitCollection(traitsFrom: [
                UITraitCollection(userInterfaceStyle: .dark),
                UITraitCollection(preferredContentSizeCategory: scale.category),
            ])
            withSnapshotTesting(record: .failed) {
                assertSnapshot(
                    of: view,
                    as: .wait(
                        for: 0.2,
                        on: .image(
                            drawHierarchyInKeyWindow: true,
                            precision: 0.95,
                            perceptualPrecision: 0.5,
                            layout: .device(config: SnapshotDevice.smallPhone.config),
                            traits: traits
                        )
                    ),
                    named: "dark-\(scale.rawValue)-smallPhone",
                    testName: "homeClear"
                )
            }
        }
    }

}
