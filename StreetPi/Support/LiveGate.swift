import Foundation

enum LiveGate {
    /// Tests, previews, and the snapshot host stay on fixtures. The installed app does not.
    static var usesFixtures: Bool {
        let environment = ProcessInfo.processInfo.environment
        if environment["XCTestConfigurationFilePath"] != nil { return true }
        if environment["XCTestBundlePath"] != nil { return true }
        if environment["XCTestSessionIdentifier"] != nil { return true }
        if environment["STREETPI_FIXTURES"] == "1" { return true }
        if environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" { return true }
        return NSClassFromString("XCTestCase") != nil
    }
}
