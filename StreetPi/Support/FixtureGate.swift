import Foundation

/// Tests and previews stay on fixtures. A normal launch reads the Pi.
enum FixtureGate {
    static var isFixtureRun: Bool {
        let environment = ProcessInfo.processInfo.environment
        if environment["XCTestConfigurationFilePath"] != nil { return true }
        if environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { return true }
        if environment["STREETPI_DISABLE_NETWORK"] == "1" { return true }
        if NSClassFromString("XCTestCase") != nil { return true }
        return false
    }
}
