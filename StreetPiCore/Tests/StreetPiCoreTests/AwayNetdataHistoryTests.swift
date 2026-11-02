import Foundation
import XCTest
@testable import StreetPiCore

final class AwayNetdataHistoryTests: XCTestCase {
    func testDecodesOptionalSeriesAndRoundTrips() throws {
        for name in ["away-history", "away-history-netdata", "away-history-empty-netdata"] {
            let report = try FixtureBook.away(named: name)
            XCTAssertEqual(try JSONDecoder().decode(AwaySnapshot.self, from: JSONEncoder().encode(report)), report)
            let expected: Int? = name == "away-history" ? nil : (name == "away-history-netdata" ? 24 : 0)
            XCTAssertEqual(report.machine?.temperatureHistory?.count, expected)
            XCTAssertEqual(report.machine?.memoryHistory?.count, expected)
            XCTAssertEqual(report.machine?.diskHistory?.count, expected)
        }
    }

    func testOldAndEmptySeriesKeepProcessorOnly() throws {
        for name in ["away-history", "away-history-empty-netdata"] {
            let board = try board(name)
            XCTAssertEqual(board.machine.series.map(\.id), ["cpu"])
            XCTAssertEqual(board.machine.series.first?.points.count, 24)
        }
    }

    func testNewSeriesUseReportedUnitsAndHours() throws {
        let series = try board("away-history-netdata").machine.series
        XCTAssertEqual(series.map(\.id), ["cpu", "memory", "disk", "temperature"])
        XCTAssertTrue(series.allSatisfy { $0.points.map(\.hour) == Array(0...23) })
        XCTAssertEqual(try XCTUnwrap(series[1].points.first?.value), 0.42, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(series[2].points.first?.value), 0.38, accuracy: 0.0001)
        XCTAssertEqual(series[3].points.first?.value, 49)
    }

    func testSeriesAreIndependentAndMissingHoursStayMissing() throws {
        var history = try FixtureBook.away(named: "away-history-netdata")
        history.machine?.cpuHistory = []
        history.machine?.memoryHistory = nil
        history.machine?.diskHistory = []
        let temperatures = try XCTUnwrap(history.machine?.temperatureHistory)
        history.machine?.temperatureHistory = Array(temperatures.prefix(2))
        let board = AwayBoard.make(latest: try FixtureBook.away(named: "away-live"), history: history)
        XCTAssertEqual(board.machine.series.map(\.id), ["temperature"])
        XCTAssertEqual(board.machine.series.first?.points.map(\.hour), [0, 1])
        history.generatedAt = history.generatedAt.addingTimeInterval(2 * 86400)
        XCTAssertTrue(AwayBoard.make(latest: history, history: history).machine.series.isEmpty)
    }

    private func board(_ name: String) throws -> AwayBoard {
        AwayBoard.make(latest: try FixtureBook.away(named: "away-live"), history: try FixtureBook.away(named: name))
    }
}
