import Foundation

/// Preview and snapshot stand-in. The installed app does not use this.
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
                StatusSection(name: "Streaming", monitors: [
                    StatusMonitor(id: 1, name: "Films", type: "http"),
                ]),
                StatusSection(name: "Smart home", monitors: [
                    StatusMonitor(id: 2, name: "Lights", type: "http"),
                ]),
                StatusSection(name: "Remote help", monitors: [
                    StatusMonitor(id: 3, name: "Desk", type: "http"),
                ]),
                StatusSection(name: "Internet", monitors: [
                    StatusMonitor(id: 4, name: "DuckDNS points home", type: "http"),
                    StatusMonitor(id: 5, name: "Name lookup", type: "dns"),
                ]),
                StatusSection(name: "Backups", monitors: [
                    StatusMonitor(id: 6, name: "Weekly SD backup", type: "push"),
                ]),
            ]
        )
    }

    public static func previewHistory() -> StatusHistory {
        let backup = backupSampleDate()
        var latest: [Int: StatusBeat] = [:]
        var successes: [Int: StatusBeat] = [:]
        for monitorID in 1...6 {
            let time = monitorID == 6 ? backup : Date.streetFixtureNow
            let beat = StatusBeat(status: 1, time: time)
            latest[monitorID] = beat
            successes[monitorID] = beat
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
}
