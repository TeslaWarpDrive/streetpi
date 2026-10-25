import Foundation
import StreetPiCore

enum StatusPageStore {
    private static let hostKey = "streetpi.statusPage.host"
    private static let portKey = "streetpi.statusPage.port"
    private static let slugKey = "streetpi.statusPage.slug"

    static func current() -> StatusPageEndpoint {
        let defaults = UserDefaults.standard
        let host = defaults.string(forKey: hostKey) ?? StatusPageEndpoint.house.host
        let port = defaults.object(forKey: portKey) as? Int ?? StatusPageEndpoint.house.port
        let slug = defaults.string(forKey: slugKey) ?? StatusPageEndpoint.house.slug
        return StatusPageEndpoint(host: host, port: port, slug: slug).cleaned() ?? .house
    }

    static func save(_ endpoint: StatusPageEndpoint) {
        guard let clean = endpoint.cleaned() else { return }
        let defaults = UserDefaults.standard
        defaults.set(clean.host, forKey: hostKey)
        defaults.set(clean.port, forKey: portKey)
        defaults.set(clean.slug, forKey: slugKey)
    }
}
