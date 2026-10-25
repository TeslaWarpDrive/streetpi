import Foundation
import StreetPiCore

enum StatusPageSlugStore {
    private static let slugKey = "settings.live.statusPageSlug"

    static func current() -> String {
        let stored = UserDefaults.standard.string(forKey: slugKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let stored, StatusPageEndpoint.isSlug(stored) else { return "house" }
        return stored
    }

    static func save(_ slug: String) {
        guard StatusPageEndpoint.isSlug(slug) else { return }
        UserDefaults.standard.set(slug, forKey: slugKey)
    }
}
