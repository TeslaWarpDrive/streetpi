import StreetPiCore

/// The four places in the shell. Alerts stay on House and open as a sheet.
enum HouseTab: String, CaseIterable, Identifiable, Hashable {
    case house
    case adBlocker
    case pi
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .house:
            "House"
        case .adBlocker:
            "Ad blocker"
        case .pi:
            "Pi"
        case .settings:
            "Settings"
        }
    }

    var symbol: String {
        switch self {
        case .house:
            "house.fill"
        case .adBlocker:
            "shield.lefthalf.filled"
        case .pi:
            "cpu"
        case .settings:
            "gearshape"
        }
    }

    var section: AppSection {
        switch self {
        case .house:
            .home
        case .adBlocker:
            .group(.adBlockerAndDNS)
        case .pi:
            .group(.piHealth)
        case .settings:
            .settings
        }
    }

    init(section: AppSection) {
        switch section {
        case .home, .alerts:
            self = .house
        case .settings:
            self = .settings
        case .group(.adBlockerAndDNS):
            self = .adBlocker
        case .group(.piHealth):
            self = .pi
        case .group:
            self = .house
        }
    }
}
