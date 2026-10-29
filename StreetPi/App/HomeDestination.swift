import StreetPiCore

/// Home drill-downs stay in the House stack, so the system back action preserves their origin.
enum HomeDestination: Hashable {
    case room(HouseGroup)
    case machine(MachinePage)
    case devices
    case settings
}
