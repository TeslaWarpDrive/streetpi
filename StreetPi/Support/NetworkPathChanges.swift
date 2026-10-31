import Foundation
import Network

/// One event each time the phone moves to a different kind of network. The first reading is the
/// starting point, not a change. No Wi-Fi name is read.
enum NetworkPathChanges {
    private struct Shape: Equatable {
        var satisfied: Bool
        var wifi: Bool
        var cellular: Bool
        var other: Bool

        init(_ path: NWPath) {
            satisfied = path.status == .satisfied
            wifi = path.usesInterfaceType(.wifi)
            cellular = path.usesInterfaceType(.cellular)
            other = path.usesInterfaceType(.wiredEthernet) || path.usesInterfaceType(.other)
        }
    }

    private final class Latest: @unchecked Sendable {
        private let lock = NSLock()
        private var shape: Shape?

        /// True when this shape is a change from a known one.
        func changed(to next: Shape) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            let known = shape
            shape = next
            return known != nil && known != next
        }
    }

    static func stream() -> AsyncStream<Void> {
        AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            let monitor = NWPathMonitor()
            let latest = Latest()
            monitor.pathUpdateHandler = { path in
                if latest.changed(to: Shape(path)) {
                    continuation.yield()
                }
            }
            continuation.onTermination = { _ in monitor.cancel() }
            monitor.start(queue: DispatchQueue(label: "streetpi.network-path"))
        }
    }
}
