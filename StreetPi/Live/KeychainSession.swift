import Foundation
import StreetPiCore

/// Session id and app password in the Keychain. Descriptions never include either value.
struct KeychainSession: Sendable, CustomStringConvertible, CustomDebugStringConvertible {
    static let sessionAccount = "pihole.session-id"

    private let store: any SecretStoring

    init(store: any SecretStoring = KeychainSecretStore()) {
        self.store = store
    }

    var description: String { "KeychainSession" }
    var debugDescription: String { "KeychainSession" }

    func saveSessionID(_ sessionID: String) throws {
        try save(sessionID, account: Self.sessionAccount)
    }

    func loadSessionID() throws -> String? {
        try text(for: Self.sessionAccount)
    }

    func deleteSessionID() throws {
        try store.delete(for: Self.sessionAccount)
    }

    func saveAppPassword(_ password: String) throws {
        try save(password, account: AppPassword.account)
    }

    func loadAppPassword() throws -> String? {
        try text(for: AppPassword.account)
    }

    func deleteAppPassword() throws {
        try store.delete(for: AppPassword.account)
    }

    func hasSessionID() throws -> Bool {
        try store.load(for: Self.sessionAccount) != nil
    }

    func hasAppPassword() throws -> Bool {
        try store.load(for: AppPassword.account) != nil
    }

    private func save(_ value: String, account: String) throws {
        guard !value.isEmpty else { throw SecretStoreError.failed }
        try store.save(Data(value.utf8), for: account)
    }

    private func text(for account: String) throws -> String? {
        guard let data = try store.load(for: account) else { return nil }
        guard let value = String(data: data, encoding: .utf8) else { throw SecretStoreError.failed }
        return value
    }
}
