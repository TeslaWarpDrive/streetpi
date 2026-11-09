import Foundation

/// The background meter loop. A miss backs off on this road and does not look for another.
public enum MeterRoad {
    public static func missAsksForNewRoad() -> Bool {
        false
    }
}
