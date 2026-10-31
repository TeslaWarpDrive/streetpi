import StreetPiCore
import XCTest
@testable import StreetPi

private final class RefusingStore: SecretStoring, @unchecked Sendable {
    var refuses = true
    private let memory = MemorySecretStore()

    func save(_ secret: Data, for account: String) throws {
        if refuses { throw SecretStoreError.failed }
        try memory.save(secret, for: account)
    }

    func load(for account: String) throws -> Data? {
        try memory.load(for: account)
    }

    func delete(for account: String) throws {
        try memory.delete(for: account)
    }
}

final class MailboxSeedingTests: XCTestCase {
    private let suite = "streetpi.tests.mailbox-seed"
    private var defaults = UserDefaults()

    override func setUpWithError() throws {
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
    }

    private func seed(token: String = "fixture-not-a-real-read-token") throws -> MailboxSeed {
        let fields = ["mailboxURL": "https://mailbox.example.test", "readToken": token]
        let data = try PropertyListSerialization.data(fromPropertyList: fields, format: .xml, options: 0)
        return try XCTUnwrap(MailboxSeed(plist: data))
    }

    private func settings(_ secrets: any SecretStoring) -> MailboxSettingsStore {
        MailboxSettingsStore(store: secrets, defaults: defaults)
    }

    func testAnEmptyPhoneIsFilledFromTheBuild() throws {
        let store = settings(MemorySecretStore())
        store.seedIfNeeded(from: try seed())
        XCTAssertEqual(store.load(), try seed().setup)
        XCTAssertTrue(store.tokenSaved())
    }

    func testABuildWithNoSeedLeavesAwayOff() {
        let store = settings(MemorySecretStore())
        store.seedIfNeeded(from: nil)
        XCTAssertNil(store.load())
    }

    func testATypedMailboxIsKept() throws {
        let store = settings(MemorySecretStore())
        XCTAssertEqual(store.save(address: "https://typed.example.test", token: "typed-fixture-token"), .saved)
        store.seedIfNeeded(from: try seed())
        XCTAssertEqual(store.addressText(), "https://typed.example.test")
        XCTAssertEqual(store.load()?.token.secret, "typed-fixture-token")
    }

    func testRemovingASeededMailboxSticks() throws {
        let store = settings(MemorySecretStore())
        store.seedIfNeeded(from: try seed())
        XCTAssertEqual(store.remove(), .saved)
        store.seedIfNeeded(from: try seed())
        XCTAssertNil(store.load())
    }

    func testRemovingATypedMailboxSticks() throws {
        let store = settings(MemorySecretStore())
        XCTAssertEqual(store.save(address: "https://typed.example.test", token: "typed-fixture-token"), .saved)
        XCTAssertEqual(store.remove(), .saved)
        store.seedIfNeeded(from: try seed())
        XCTAssertNil(store.load())
    }

    func testAReplacedSeedIsNotPutBack() throws {
        let store = settings(MemorySecretStore())
        store.seedIfNeeded(from: try seed())
        XCTAssertEqual(store.save(address: "https://typed.example.test", token: "typed-fixture-token"), .saved)
        store.seedIfNeeded(from: try seed(token: "newer-fixture-token"))
        XCTAssertEqual(store.load()?.token.secret, "typed-fixture-token")
    }

    func testAFailedKeychainSaveTriesAgain() throws {
        let secrets = RefusingStore()
        let store = settings(secrets)
        store.seedIfNeeded(from: try seed())
        XCTAssertNil(store.load())
        secrets.refuses = false
        store.seedIfNeeded(from: try seed())
        XCTAssertNotNil(store.load())
    }

    func testAnAddressLostWithTheTokenStillSavedIsRefilled() throws {
        let secrets = MemorySecretStore()
        XCTAssertEqual(settings(secrets).save(address: "https://old.example.test", token: "old-fixture-token"), .saved)
        defaults.removePersistentDomain(forName: suite)
        let store = settings(secrets)
        store.seedIfNeeded(from: try seed())
        XCTAssertEqual(store.load(), try seed().setup)
    }

    func testTheAppBundleCarriesNoSeed() {
        XCTAssertNil(MailboxSeed.bundled())
    }
}
