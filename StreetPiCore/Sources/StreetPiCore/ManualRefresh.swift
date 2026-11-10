import Foundation

/// What a pull reads when the road on screen stays put.
/// A different road restarts the watch, so it is not decided here.
public enum ManualRefresh {
    public enum Source: Sendable, Equatable, Hashable {
        case adBlocker
        case mailbox
        case temperature
        case charts
        case monitors
    }

    /// The road and the saved settings a manual read belongs to.
    /// A result is dropped when any of these change before it is published.
    public struct Identity: Sendable, Equatable {
        public let mode: ConnectionMode
        /// Bumps when that road is replaced or the gateway settings change.
        public let generation: Int
        /// The saved Pi address. A new address is a different machine.
        public let host: String
        public let statusAddress: String
        public let statusSlug: String
        /// Bumps when the watch restarts, including a network change that has not picked a road yet.
        public let watch: Int
        public let signedOut: Bool
        /// Bumps when saved settings or the app password replace the session.
        public let retry: Int

        public init(
            mode: ConnectionMode,
            generation: Int,
            host: String,
            statusAddress: String,
            statusSlug: String,
            watch: Int,
            signedOut: Bool,
            retry: Int
        ) {
            self.mode = mode
            self.generation = generation
            self.host = host
            self.statusAddress = statusAddress
            self.statusSlug = statusSlug
            self.watch = watch
            self.signedOut = signedOut
            self.retry = retry
        }
    }

    /// The mailbox snapshot already carries the tiles, so that road stays one read.
    /// Signed out still reads nothing.
    public static func reads(mode: ConnectionMode, signedOut: Bool) -> Set<Source> {
        if case .awayMailbox = mode {
            return [.mailbox]
        }
        guard signedOut == false else { return [] }
        return [.adBlocker, .temperature, .charts, .monitors]
    }

    /// One tile's read, and where a current result is published.
    @MainActor
    public struct Tile<Value> {
        public let load: @MainActor () async -> Value?
        public let publish: @MainActor (Value) -> Void

        public init(
            load: @escaping @MainActor () async -> Value?,
            publish: @escaping @MainActor (Value) -> Void
        ) {
            self.load = load
            self.publish = publish
        }
    }

    /// Temperature, charts, and monitors, together.
    /// Each result is published only while its road and settings are still current.
    /// Nil is a miss or a cancel and is not published. The call waits for every asked read.
    @MainActor
    public static func refreshTiles<Temperature, Charts, Monitors>(
        reads: Set<Source>,
        identity: @escaping @MainActor () -> Identity,
        temperature: Tile<Temperature>,
        charts: Tile<Charts>,
        monitors: Tile<Monitors>
    ) async {
        async let temperatureRead: Void = publishIfCurrent(
            .temperature, reads: reads, identity: identity, tile: temperature
        )
        async let chartsRead: Void = publishIfCurrent(
            .charts, reads: reads, identity: identity, tile: charts
        )
        async let monitorsRead: Void = publishIfCurrent(
            .monitors, reads: reads, identity: identity, tile: monitors
        )
        _ = await (temperatureRead, chartsRead, monitorsRead)
    }

    @MainActor
    private static func publishIfCurrent<Value>(
        _ source: Source,
        reads: Set<Source>,
        identity: @escaping @MainActor () -> Identity,
        tile: Tile<Value>
    ) async {
        guard reads.contains(source) else { return }
        let started = identity()
        guard let value = await tile.load() else { return }
        guard Task.isCancelled == false, identity() == started else { return }
        tile.publish(value)
    }
}
