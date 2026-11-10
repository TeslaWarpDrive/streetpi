import Foundation
import XCTest
@testable import StreetPiCore

final class AwayNoticeRecoveryTests: XCTestCase {
    private func gateway() throws -> AwayGatewaySettings {
        try XCTUnwrap(AwayGatewaySettings(
            url: "https://gateway.example.test",
            clientID: "test-client.access",
            clientSecret: "cfast_FAKE_not_a_real_secret"
        ))
    }

    private func mailbox() throws -> MailboxSetup {
        MailboxSetup(
            address: try XCTUnwrap(MailboxAddress(text: "https://mailbox.example.test")),
            token: try XCTUnwrap(MailboxToken(text: "FAKE_mailbox_token"))
        )
    }

    func testAnyRoadLooksAgainAfterAFailedRead() throws {
        for mode in [ConnectionMode.home, .offline, .awayLive(try gateway()), .awayMailbox(try mailbox())] {
            XCTAssertTrue(mode.looksAgain(readFailed: true, keyRejected: false))
        }
    }

    func testARejectedKeyKeepsTheAppLookingEvenWhenTheReadWorked() throws {
        for mode in [ConnectionMode.awayLive(try gateway()), .awayMailbox(try mailbox())] {
            XCTAssertTrue(mode.looksAgain(readFailed: false, keyRejected: true))
        }
    }

    func testOfflineKeepsLookingWhenTheHouseAnswers() {
        XCTAssertTrue(ConnectionMode.offline.looksAgain(readFailed: false, keyRejected: false))
    }

    /// The badge stays "Can't reach the Pi" on this road. One row changes: a read that
    /// worked stays off the house. A miss still shows, and every other road paints both.
    func testOnlyAnOfflineSuccessStaysOffTheHouse() throws {
        let gateway = try gateway()
        let mailbox = try mailbox()
        let rows = [
            PaintRow(mode: .home, succeeded: true, paints: true),
            PaintRow(mode: .home, succeeded: false, paints: true),
            PaintRow(mode: .awayLive(gateway), succeeded: true, paints: true),
            PaintRow(mode: .awayLive(gateway), succeeded: false, paints: true),
            PaintRow(mode: .awayMailbox(mailbox), succeeded: true, paints: true),
            PaintRow(mode: .awayMailbox(mailbox), succeeded: false, paints: true),
            PaintRow(mode: .offline, succeeded: false, paints: true),
            PaintRow(mode: .offline, succeeded: true, paints: false),
        ]
        for row in rows {
            XCTAssertEqual(row.mode.paintsHouse(readSucceeded: row.succeeded), row.paints)
        }
    }

    /// A successful log half stays off the desk while the badge says the Pi is out of reach.
    /// A miss on the other half, or a later miss that returns the withheld feed, still must not publish it.
    func testAnOfflineLogSuccessStaysOffTheDesk() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let older = DNSQuery(id: "1", domain: "old.example.test", client: "Kitchen", outcome: .allowed, at: now)
        let fresh = DNSQuery(
            id: "9", domain: "news.example.test", client: "Kitchen", outcome: .allowed, at: now.addingTimeInterval(5)
        )
        let liveMiss = "The live log could not be read."
        let textMiss = "The text log could not be read."
        let desk = DNSDesk.quiet

        let liveSucceeded = desk.applyingLiveLog(
            queries: LiveLogFeed(queries: [fresh]),
            liveNote: nil,
            text: TextLogFeed(lines: ["gravity updated"], fileEnabled: true),
            textNote: textMiss,
            mode: .offline
        )
        XCTAssertNil(liveSucceeded.liveFeed)
        XCTAssertNil(liveSucceeded.liveReadNote)
        XCTAssertEqual(liveSucceeded.textLogLines, [])
        XCTAssertFalse(liveSucceeded.textLogKnown)
        XCTAssertFalse(liveSucceeded.textLogFileEnabled)
        XCTAssertEqual(liveSucceeded.textLogReadNote, textMiss)

        let textSucceeded = desk.applyingLiveLog(
            queries: LiveLogFeed(queries: [fresh]),
            liveNote: liveMiss,
            text: TextLogFeed(lines: ["gravity updated"], fileEnabled: true),
            textNote: nil,
            mode: .offline
        )
        XCTAssertNil(textSucceeded.liveFeed)
        XCTAssertEqual(textSucceeded.liveReadNote, liveMiss)
        XCTAssertEqual(textSucceeded.textLogLines, [])
        XCTAssertFalse(textSucceeded.textLogKnown)
        XCTAssertFalse(textSucceeded.textLogFileEnabled)
        XCTAssertNil(textSucceeded.textLogReadNote)

        var shown = DNSDesk.quiet
        shown.liveFeed = [older]
        shown.textLogLines = ["already shown"]
        shown.textLogKnown = true
        let withheld = shown.applyingLiveLog(
            queries: LiveLogFeed(queries: [fresh, older]),
            liveNote: nil,
            text: TextLogFeed(lines: ["already shown", "new line"], fileEnabled: true),
            textNote: nil,
            mode: .offline
        )
        XCTAssertEqual(withheld.liveFeed, [older])
        XCTAssertEqual(withheld.textLogLines, ["already shown"])
        XCTAssertTrue(withheld.textLogKnown)
        XCTAssertNil(withheld.liveReadNote)
        XCTAssertNil(withheld.textLogReadNote)

        let later = withheld.applyingLiveLog(
            queries: LiveLogFeed(queries: [fresh, older]),
            liveNote: LiveReadCopy.offline,
            text: TextLogFeed(lines: ["already shown", "new line"], fileEnabled: true),
            textNote: LiveReadCopy.offline,
            mode: .offline
        )
        XCTAssertEqual(later.liveFeed, [older])
        XCTAssertEqual(later.textLogLines, ["already shown"])
        XCTAssertTrue(later.textLogKnown)
        XCTAssertEqual(later.liveReadNote, LiveReadCopy.offline)
        XCTAssertEqual(later.textLogReadNote, LiveReadCopy.offline)

        for mode in [ConnectionMode.home, .awayLive(try gateway()), .awayMailbox(try mailbox())] {
            let painted = desk.applyingLiveLog(
                queries: LiveLogFeed(queries: [fresh]),
                liveNote: nil,
                text: TextLogFeed(lines: ["gravity updated"], fileEnabled: true),
                textNote: nil,
                mode: mode
            )
            XCTAssertEqual(painted.liveFeed, [fresh])
            XCTAssertEqual(painted.textLogLines, ["gravity updated"])
            XCTAssertTrue(painted.textLogKnown)
            XCTAssertTrue(painted.textLogFileEnabled)
            XCTAssertNil(painted.liveReadNote)
            XCTAssertNil(painted.textLogReadNote)
        }
    }

    func testHomeStaysPutOnAGoodRead() {
        XCTAssertFalse(ConnectionMode.home.looksAgain(readFailed: false, keyRejected: false))
    }

    func testAHealthyLiveGatewayKeepsLookingForHome() throws {
        XCTAssertTrue(ConnectionMode.awayLive(try gateway()).looksAgain(readFailed: false, keyRejected: false))
    }

    /// A failed ad-blocker poll's desk is empty. Offline keeps pause and the day's counts.
    /// Home still takes that poll. A success while offline stays off the desk too.
    /// Offline does not record the failure, so a later success is not asked to clear it.
    func testAFailedAdBlockerPollDoesNotEmptyTheDeskWhileOffline() throws {
        var shown = DNSDesk.houseFixture
        shown.blocking = DNSBlocking(
            enabled: false, pause: .fiveMinutes, pauseEndsAt: Date(timeIntervalSince1970: 1_700_000_300)
        )
        let empty = DNSDesk.quiet
        XCTAssertTrue(empty.queries.isEmpty)
        XCTAssertFalse(shown.queries.isEmpty)

        let kept = shown.applyingAdBlockerPoll(empty, failed: true, mode: .offline)
        XCTAssertEqual(kept.blocking, shown.blocking)
        XCTAssertEqual(kept.queries, shown.queries)
        XCTAssertFalse(ConnectionMode.offline.takesAdBlockerDesk(pollFailed: true))
        XCTAssertFalse(ConnectionMode.offline.recordsAdBlockerProblem(pollFailed: true))
        XCTAssertFalse(ConnectionMode.offline.recordsAdBlockerProblem(pollFailed: false))

        let home = shown.applyingAdBlockerPoll(empty, failed: true, mode: .home)
        XCTAssertEqual(home.queries, empty.queries)
        XCTAssertTrue(home.blocking.enabled)
        XCTAssertTrue(ConnectionMode.home.takesAdBlockerDesk(pollFailed: true))
        XCTAssertTrue(ConnectionMode.home.recordsAdBlockerProblem(pollFailed: true))
        XCTAssertFalse(ConnectionMode.home.recordsAdBlockerProblem(pollFailed: false))
        XCTAssertTrue(ConnectionMode.awayLive(try gateway()).takesAdBlockerDesk(pollFailed: true))
        XCTAssertTrue(ConnectionMode.awayLive(try gateway()).recordsAdBlockerProblem(pollFailed: true))
        XCTAssertTrue(ConnectionMode.awayMailbox(try mailbox()).takesAdBlockerDesk(pollFailed: false))
        XCTAssertTrue(ConnectionMode.awayMailbox(try mailbox()).recordsAdBlockerProblem(pollFailed: true))
        XCTAssertFalse(ConnectionMode.offline.takesAdBlockerDesk(pollFailed: false))
    }

    /// Charts and the log are one pass. A half that succeeded stays off the house while the
    /// other half missed. A later miss does not publish the withheld half either.
    func testASplitChartsAndLogPassDoesNotWriteTheSuccessfulHalf() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let older = DNSQuery(id: "1", domain: "old.example.test", client: "Kitchen", outcome: .allowed, at: now)
        let fresh = DNSQuery(
            id: "9", domain: "news.example.test", client: "Kitchen", outcome: .allowed, at: now.addingTimeInterval(5)
        )
        var desk = DNSDesk.quiet
        desk.liveFeed = [older]
        desk.textLogLines = ["already shown"]
        desk.textLogKnown = true
        var machine = MachineDesk.quiet
        let oldSeries = MetricSeries(id: "cpu", title: "Processor", caption: "Already shown", points: [])
        let newSeries = MetricSeries(
            id: "cpu", title: "Processor", caption: "Just read",
            points: [MetricPoint(hour: 1, value: 0.4)]
        )
        let oldContainer = NamedRow(id: "old", name: "Old helper", detail: "Running")
        let newContainer = NamedRow(id: "media", name: "Media helper", detail: "Running")
        machine.series = [oldSeries]
        machine.containers = [oldContainer]
        let newAlert = HouseAlert(id: "heat", sentence: "The Pi is warm.", tone: .attention)

        let chartsWorked = HousePass(
            series: [newSeries], chartNote: nil,
            containers: [newContainer], containerNote: nil,
            alerts: [newAlert], alertNote: nil,
            queries: LiveLogFeed(queries: [fresh, older]), liveNote: LiveReadCopy.liveLog,
            text: TextLogFeed(lines: ["already shown", "new line"], fileEnabled: true), textNote: nil
        ).applied(to: machine, desk: desk, mode: .offline)
        XCTAssertEqual(chartsWorked.machine.series, [oldSeries])
        XCTAssertEqual(chartsWorked.machine.containers, [oldContainer])
        XCTAssertEqual(chartsWorked.machine.alerts, [])
        XCTAssertNil(chartsWorked.machine.chartNote)
        XCTAssertNil(chartsWorked.machine.containerNote)
        XCTAssertNil(chartsWorked.machine.alertNote)
        XCTAssertEqual(chartsWorked.desk.liveFeed, [older])
        XCTAssertEqual(chartsWorked.desk.liveReadNote, LiveReadCopy.liveLog)
        XCTAssertEqual(chartsWorked.desk.textLogLines, ["already shown"])
        XCTAssertTrue(chartsWorked.desk.textLogKnown)
        XCTAssertNil(chartsWorked.desk.textLogReadNote)

        let logWorked = HousePass(
            series: [newSeries], chartNote: LiveReadCopy.charts,
            containers: [newContainer], containerNote: nil,
            alerts: [newAlert], alertNote: LiveReadCopy.alarms,
            queries: LiveLogFeed(queries: [fresh, older]), liveNote: nil,
            text: TextLogFeed(lines: ["already shown", "new line"], fileEnabled: true), textNote: nil
        ).applied(to: machine, desk: desk, mode: .offline)
        XCTAssertEqual(logWorked.machine.series, [oldSeries])
        XCTAssertEqual(logWorked.machine.chartNote, LiveReadCopy.charts)
        XCTAssertEqual(logWorked.machine.containers, [oldContainer])
        XCTAssertNil(logWorked.machine.containerNote)
        XCTAssertEqual(logWorked.machine.alerts, [])
        XCTAssertEqual(logWorked.machine.alertNote, LiveReadCopy.alarms)
        XCTAssertEqual(logWorked.desk.liveFeed, [older])
        XCTAssertNil(logWorked.desk.liveReadNote)
        XCTAssertEqual(logWorked.desk.textLogLines, ["already shown"])

        let home = HousePass(
            series: [newSeries], chartNote: nil,
            containers: [newContainer], containerNote: nil,
            alerts: [newAlert], alertNote: nil,
            queries: LiveLogFeed(queries: [fresh]), liveNote: nil,
            text: TextLogFeed(lines: ["gravity updated"], fileEnabled: true), textNote: nil
        ).applied(to: machine, desk: desk, mode: .home)
        XCTAssertEqual(home.machine.series, [newSeries])
        XCTAssertEqual(home.machine.containers, [newContainer])
        XCTAssertEqual(home.machine.alerts, [newAlert])
        XCTAssertNil(home.machine.chartNote)
        XCTAssertEqual(home.desk.liveFeed, [fresh, older])
        XCTAssertEqual(home.desk.textLogLines, ["gravity updated"])
        XCTAssertTrue(home.desk.textLogKnown)
    }

    func testAPullKeepsAChartReadThatWorkedOffTheHouseWhileOffline() {
        var machine = MachineDesk.quiet
        let oldSeries = MetricSeries(id: "cpu", title: "Processor", caption: "Already shown", points: [])
        let newSeries = MetricSeries(
            id: "cpu", title: "Processor", caption: "Just read",
            points: [MetricPoint(hour: 1, value: 0.4)]
        )
        let oldContainer = NamedRow(id: "old", name: "Old helper", detail: "Running")
        let newContainer = NamedRow(id: "media", name: "Media helper", detail: "Running")
        let newAlert = HouseAlert(id: "heat", sentence: "The Pi is warm.", tone: .attention)
        machine.series = [oldSeries]
        machine.containers = [oldContainer]
        let pulled = NetdataHistoryLoad(
            series: [newSeries], containers: [newContainer], alerts: [newAlert],
            chartNote: nil, containerNote: nil, alertNote: LiveReadCopy.alarms
        )

        let offline = HousePass(history: pulled).appliedHistory(to: machine, mode: .offline)
        XCTAssertEqual(offline.series, [oldSeries])
        XCTAssertNil(offline.chartNote)
        XCTAssertEqual(offline.containers, [oldContainer])
        XCTAssertEqual(offline.alerts, [])
        XCTAssertEqual(offline.alertNote, LiveReadCopy.alarms)

        let home = HousePass(history: pulled).appliedHistory(to: machine, mode: .home)
        XCTAssertEqual(home.series, [newSeries])
        XCTAssertEqual(home.containers, [newContainer])
        XCTAssertEqual(home.alerts, [])
        XCTAssertEqual(home.alertNote, LiveReadCopy.alarms)
    }

    func testTheLiveLogStartsAgainAfterBackgrounding() {
        let watching = LiveLogWatch(onLiveLog: true, modeCheck: 3, phoneIsActive: true)
        let background = LiveLogWatch(onLiveLog: true, modeCheck: 3, phoneIsActive: false)
        XCTAssertTrue(watching.runs)
        XCTAssertFalse(background.runs)
        XCTAssertNotEqual(watching.token, background.token)
        let back = LiveLogWatch(onLiveLog: true, modeCheck: 3, phoneIsActive: true)
        XCTAssertEqual(back.token, watching.token)
        XCTAssertTrue(back.runs)
        let otherPage = LiveLogWatch(onLiveLog: false, modeCheck: 3, phoneIsActive: true)
        XCTAssertFalse(otherPage.runs)
        XCTAssertNotEqual(otherPage.token, watching.token)
    }
}

private struct PaintRow {
    var mode: ConnectionMode
    var succeeded: Bool
    var paints: Bool
}
