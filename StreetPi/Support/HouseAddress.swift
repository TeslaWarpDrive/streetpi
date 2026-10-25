import Foundation
import StreetPiCore

enum HouseAddress {
    private static let hostKey = "streetpi.netdata.host"
    private static let portKey = "streetpi.netdata.port"

    static func current() -> NetdataEndpoint {
        let defaults = UserDefaults.standard
        let host = defaults.string(forKey: hostKey) ?? NetdataEndpoint.houseDefault.host
        let storedPort = defaults.object(forKey: portKey) as? Int ?? NetdataEndpoint.houseDefault.port
        let endpoint = NetdataEndpoint(host: host, port: storedPort)
        return endpoint.isLocalAgent ? endpoint : .houseDefault
    }

    static func save(_ endpoint: NetdataEndpoint) {
        guard endpoint.isLocalAgent else { return }
        let defaults = UserDefaults.standard
        defaults.set(endpoint.host, forKey: hostKey)
        defaults.set(endpoint.port, forKey: portKey)
    }
}
