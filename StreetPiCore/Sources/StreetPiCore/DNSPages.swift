import Foundation

public enum DNSPage: String, CaseIterable, Sendable, Equatable, Identifiable, Codable {
    case today
    case statistics
    case queryLog
    case liveLog
    case services
    case clients
    case groups
    case domains
    case lists
    case localNames
    case upkeep

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .today: "Today"
        case .statistics: "Statistics"
        case .queryLog: "Query log"
        case .liveLog: "Live log"
        case .services: "Services"
        case .clients: "Clients"
        case .groups: "Groups"
        case .domains: "Domains"
        case .lists: "Block lists"
        case .localNames: "Local names"
        case .upkeep: "Upkeep"
        }
    }

    public var blurb: String {
        switch self {
        case .today: "Blocking, and the last day of lookups."
        case .statistics: "The busiest names and devices."
        case .queryLog: "Lookups the Pi has kept."
        case .liveLog: "Lookups as they happen."
        case .services: "Kinds of sites the house refuses."
        case .clients: "Devices the house knows."
        case .groups: "Devices that share a rule."
        case .domains: "Names to block or allow."
        case .lists: "Lists the filter uses."
        case .localNames: "Names that stay inside the house."
        case .upkeep: "Update the block lists. Other settings on the Pi stay as they are."
        }
    }

    public var symbolName: String {
        switch self {
        case .today: "chart.bar"
        case .statistics: "list.bullet"
        case .queryLog: "text.magnifyingglass"
        case .liveLog: "waveform"
        case .services: "hand.raised"
        case .clients: "laptopcomputer"
        case .groups: "square.stack.3d.up"
        case .domains: "globe"
        case .lists: "list.clipboard"
        case .localNames: "house"
        case .upkeep: "wrench.and.screwdriver"
        }
    }
}

public enum DNSShelf: String, CaseIterable, Sendable, Identifiable {
    case picture
    case lookups
    case rules
    case care

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .picture: "Picture"
        case .lookups: "Lookups"
        case .rules: "Rules"
        case .care: "Care"
        }
    }

    public var pages: [DNSPage] {
        switch self {
        case .picture: [.today, .statistics]
        case .lookups: [.queryLog, .liveLog]
        case .rules: [.services, .clients, .groups, .domains, .lists, .localNames]
        case .care: [.upkeep]
        }
    }
}
