import Foundation

/// Preview and snapshot stand-in. The installed app does not use this.
/// The shape matches the live house page: five named sections and 28 monitors.
public enum StatusPageFixture {
    public static func previewBoard(now: Date = .streetFixtureNow) -> HouseStatusBoard {
        HouseStatusBoard.make(document: previewDocument(), history: previewHistory(), now: now)
    }

    public static func previewSnapshot(now: Date = .streetFixtureNow) -> HouseholdSnapshot {
        let board = previewBoard(now: now)
        return HouseholdSnapshot(
            capturedAt: now,
            link: .homeNetwork,
            services: board.services,
            machine: nil,
            dns: nil
        )
    }

    public static func previewDocument() -> StatusPageDocument {
        StatusPageDocument(
            title: "House",
            published: true,
            sections: [
                section("Streaming", ids: Array(1...8)),
                section("Smart home", ids: Array(9...16)),
                section("Remote help", ids: Array(17...22)),
                section(
                    "Internet",
                    ids: Array(23...27),
                    named: [27: ("DuckDNS points home", "http")]
                ),
                section(
                    "Backups",
                    ids: [28],
                    named: [28: (StatusPageCopy.backupMonitor, "push")]
                ),
            ]
        )
    }

    public static func previewHistory() -> StatusHistory {
        let backup = backupSampleDate()
        var latest: [Int: StatusBeat] = [:]
        var successes: [Int: StatusBeat] = [:]
        for section in previewDocument().sections {
            for monitor in section.monitors {
                let time = monitor.name == StatusPageCopy.backupMonitor ? backup : Date.streetFixtureNow
                let beat = StatusBeat(status: 1, time: time)
                latest[monitor.id] = beat
                successes[monitor.id] = beat
            }
        }
        return StatusHistory(latest: latest, successes: successes)
    }

    /// Tuesday 13 October 2026, 08:17 UTC, which is 3:17 AM in Chicago.
    public static func backupSampleDate() -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
        let parts = DateComponents(year: 2026, month: 10, day: 13, hour: 8, minute: 17, second: 0)
        return calendar.date(from: parts) ?? Date(timeIntervalSince1970: 0)
    }

    private static func section(
        _ name: String,
        ids: [Int],
        named: [Int: (String, String)] = [:]
    ) -> StatusSection {
        StatusSection(
            name: name,
            monitors: ids.map { id in
                if let pair = named[id] {
                    return StatusMonitor(id: id, name: pair.0, type: pair.1)
                }
                return StatusMonitor(id: id, name: "\(name) \(id)", type: "http")
            }
        )
    }
}
