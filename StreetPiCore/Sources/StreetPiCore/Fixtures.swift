import Foundation

public enum StreetJSON {
    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    public static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

public enum FixtureError: Error, Equatable {
    case missing(String)
}

public enum FixtureBook {
    public static func snapshot(named name: String) throws -> HouseholdSnapshot {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
            throw FixtureError.missing(name)
        }
        let data = try Data(contentsOf: url)
        return try StreetJSON.decoder().decode(HouseholdSnapshot.self, from: data)
    }

    public static func away(named name: String) throws -> AwaySnapshot {
        guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
            throw FixtureError.missing(name)
        }
        return try JSONDecoder().decode(AwaySnapshot.self, from: Data(contentsOf: url))
    }
}

extension HouseholdSnapshot {
    public static let healthyFixture = HouseholdSnapshot(
        capturedAt: .streetFixtureNow,
        link: .homeNetwork,
        services: .streetHouse(piHole: .responding),
        machine: MachineReading(
            cpuUsedFraction: 0.18,
            temperatureCelsius: 47.2,
            memoryUsedFraction: 0.41,
            diskUsedFraction: 0.22,
            uptimeSeconds: 1_036_800
        ),
        dns: DNSSummary(
            blockingEnabled: true,
            queriesToday: DNSDesk.houseFixture.queriesToday,
            blockedToday: DNSDesk.houseFixture.blockedToday
        )
    )

    public static let awayTroubleFixture = HouseholdSnapshot(
        capturedAt: Date(timeIntervalSince1970: 1_792_421_280),
        link: .away(cachedAt: Date(timeIntervalSince1970: 1_792_421_280)),
        services: .streetHouse(piHole: .notResponding),
        machine: MachineReading(
            cpuUsedFraction: 0.18,
            temperatureCelsius: 47.2,
            memoryUsedFraction: 0.41,
            diskUsedFraction: 0.22,
            uptimeSeconds: 1_036_800
        ),
        dns: DNSSummary(blockingEnabled: true)
    )

    public static let awayFreshFixture = HouseholdSnapshot(
        capturedAt: Date(timeIntervalSince1970: 1_792_421_280),
        link: .away(cachedAt: Date(timeIntervalSince1970: 1_792_421_280)),
        services: .streetHouse(piHole: .responding),
        machine: .streetQuiet,
        dns: DNSSummary(blockingEnabled: true)
    )

    public static let staleFixture = HouseholdSnapshot(
        capturedAt: Date.streetFixtureNow.addingTimeInterval(-2 * 86_400),
        link: .homeNetwork,
        services: .streetHouse(piHole: .responding),
        machine: .streetQuiet,
        dns: DNSSummary(blockingEnabled: true)
    )

    public static let emptyFixture = HouseholdSnapshot(
        capturedAt: .streetFixtureNow,
        link: .homeNetwork,
        services: [],
        machine: nil,
        dns: nil
    )
}

extension Array where Element == ServiceHealth {
    static func streetHouse(piHole: Reachability) -> [ServiceHealth] {
        [
            ServiceHealth(id: "pi-hole", name: "Pi-hole", kind: .dnsFilter, state: piHole),
            ServiceHealth(id: "unbound", name: "Unbound", kind: .resolver, state: .responding),
            ServiceHealth(id: "mediaflow", name: "MediaFlow", kind: .media, state: .responding),
            ServiceHealth(id: "aiostreams", name: "AIOStreams", kind: .media, state: .responding),
            ServiceHealth(id: "home-assistant", name: "Home Assistant", kind: .homeAutomation, state: .responding),
            ServiceHealth(id: "rustdesk", name: "RustDesk", kind: .remoteHelp, state: .responding),
            ServiceHealth(id: "duckdns", name: "DuckDNS", kind: .internet, state: .responding),
            ServiceHealth(id: "sd-copy", name: "Weekly SD copy", kind: .backup, state: .responding),
        ]
    }
}

extension MachineReading {
    static let streetQuiet = MachineReading(
        cpuUsedFraction: 0.18,
        temperatureCelsius: 47.2,
        memoryUsedFraction: 0.41,
        diskUsedFraction: 0.22,
        uptimeSeconds: 1_036_800
    )
}
