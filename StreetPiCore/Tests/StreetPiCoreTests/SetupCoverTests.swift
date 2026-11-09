import XCTest
@testable import StreetPiCore

final class SetupCoverTests: XCTestCase {
    func testCoverFollowsTheSavedPasswordAndTheAsk() {
        XCTAssertEqual(SetupCover(passwordSaved: false, userAsked: false), .hidden)
        XCTAssertEqual(SetupCover(passwordSaved: true, userAsked: false), .hidden)
        XCTAssertEqual(
            SetupCover(passwordSaved: false, userAsked: true),
            .showing(replacing: false)
        )
        XCTAssertEqual(
            SetupCover(passwordSaved: true, userAsked: true),
            .showing(replacing: true)
        )
    }

    func testOffersSetupIsTheMissingPassword() {
        XCTAssertTrue(SetupCover.offersSetup(passwordSaved: false))
        XCTAssertFalse(SetupCover.offersSetup(passwordSaved: true))
        for passwordSaved in [false, true] {
            for asked in [false, true] {
                let cover = SetupCover(passwordSaved: passwordSaved, userAsked: asked)
                let offers = SetupCover.offersSetup(passwordSaved: passwordSaved)
                XCTAssertEqual(offers, passwordSaved == false)
                if case .showing(let replacing) = cover {
                    XCTAssertEqual(replacing, passwordSaved)
                    XCTAssertEqual(offers, replacing == false)
                    XCTAssertTrue(cover.isShowing)
                } else {
                    XCTAssertFalse(asked)
                    XCTAssertFalse(cover.isShowing)
                }
            }
        }
    }

    func testTheCoverHasOnePresenter() {
        XCTAssertEqual(SetupCover.presenters, [.adBlockerTab])
    }

    /// Lists every ask. Clients and Settings open the one presenter. The Ad blocker tab is already there.
    func testEachAskReachesTheOnePresenter() {
        let rows: [(SetupCover.Ask, Bool)] = [
            (.adBlockerTab, false),
            (.clients, true),
            (.settings, true),
        ]
        XCTAssertEqual(rows.map(\.0), Array(SetupCover.Ask.allCases))
        for (ask, opensTab) in rows {
            let request = SetupCover.request(from: ask)
            XCTAssertEqual(request.openAdBlockerTab, opensTab, "\(ask)")
            XCTAssertTrue(request.showForm, "\(ask)")
        }
    }
}
