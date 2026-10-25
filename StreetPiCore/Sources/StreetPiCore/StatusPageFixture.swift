import Foundation

/// Preview and snapshot stand-in. The installed app does not use this.
/// Section names are what production binds. These ids are only the membership
/// recorded for the house page, so the preview can show that page.
public enum StatusPageFixture {
    public static func previewBoard(now: Date = .streetFixtureNow) -> HouseStatusBoard {
        HouseStatusBoard.make(document: previewDocument(), history: previewHistory(now: now), now: now)
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
                section("Streaming", monitors: streaming),
                section("Smart home", monitors: smartHome),
                section("Remote help", monitors: remoteHelp),
                section("Internet", monitors: internet),
                section("Backups", monitors: backups),
            ]
        )
    }

    /// Other monitors have checked in. The weekly backup has not, so this history
    /// leaves that beat out instead of inventing a time.
    public static func previewHistory(now: Date = .streetFixtureNow) -> StatusHistory {
        var latest: [Int: StatusBeat] = [:]
        var successes: [Int: StatusBeat] = [:]
        let beat = StatusBeat(status: 1, time: now)
        for section in previewDocument().sections {
            for monitor in section.monitors where monitor.name != StatusPageCopy.backupMonitor {
                latest[monitor.id] = beat
                successes[monitor.id] = beat
            }
        }
        return StatusHistory(latest: latest, successes: successes)
    }

    private static func section(_ name: String, monitors: [StatusMonitor]) -> StatusSection {
        StatusSection(name: name, monitors: monitors)
    }

    private static func monitor(_ id: Int, _ name: String, _ type: String) -> StatusMonitor {
        StatusMonitor(id: id, name: name, type: type)
    }

    private static let streaming: [StatusMonitor] = [
        monitor(3, "MediaFlow proxy (public)", "http"),
        monitor(4, "MediaFlow internal", "http"),
        monitor(5, "Container: mediaflow", "docker"),
        monitor(6, "Container: mediaflow-caddy", "docker"),
        monitor(7, "Container: mediaflow-duckdns", "docker"),
        monitor(23, "AIOStreams health (local)", "http"),
        monitor(24, "Container: aiostreams", "docker"),
        monitor(25, "AIOStreams (public)", "http"),
        monitor(29, "AIOMetadata health (local)", "http"),
        monitor(30, "AIOMetadata (public)", "http"),
        monitor(31, "Container: aiometadata", "docker"),
        monitor(32, "Container: aiometadata_redis", "docker"),
    ]

    private static let smartHome: [StatusMonitor] = [
        monitor(15, "Home Assistant", "http"),
        monitor(16, "Container: homeassistant", "docker"),
        monitor(17, "HomeKit Bridge TCP 21064", "port"),
        monitor(18, "Container: matter-server", "docker"),
        monitor(19, "Matter Server TCP 5580", "port"),
        monitor(27, "HomeKit Dyson Heat TCP 21066", "port"),
        monitor(28, "HomeKit Living Room TV TCP 21067", "port"),
    ]

    private static let remoteHelp: [StatusMonitor] = [
        monitor(8, "Container: rustdesk-hbbs-1", "docker"),
        monitor(9, "Container: rustdesk-hbbr-1", "docker"),
        monitor(11, "RustDesk relay TCP 21117", "port"),
        monitor(12, "RustDesk ID server TCP 21116", "port"),
    ]

    /// The house ping is named Internet. The audit notes that it pings 1.1.1.1.
    private static let internet: [StatusMonitor] = [
        monitor(33, "Internet", "ping"),
        monitor(1, "Pi-hole DNS", "dns"),
        monitor(13, "Unbound", "dns"),
        monitor(10, "DuckDNS points home", "http"),
    ]

    private static let backups: [StatusMonitor] = [
        monitor(34, "Weekly SD backup", "push"),
    ]
}
