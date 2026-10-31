import Foundation
import StreetPiCore

enum MailboxSaveResult: Equatable {
    case saved
    case badAddress
    case missingToken
    case failed

    var note: String {
        switch self {
        case .saved:
            "Saved."
        case .badAddress:
            "Use the mailbox's https address."
        case .missingToken:
            "Paste the read token, with no spaces."
        case .failed:
            "That could not be saved on this phone."
        }
    }
}

/// The mailbox address sits in settings. The read token sits only in the Keychain.
/// `UserDefaults` is thread-safe and is not marked `Sendable` in this SDK.
struct MailboxSettingsStore: @unchecked Sendable {
    private static let addressKey = "settings.away.mailbox"

    private let defaults: UserDefaults
    private let keychain: KeychainSession

    init(store: any SecretStoring, defaults: UserDefaults = .standard) {
        keychain = KeychainSession(store: store)
        self.defaults = defaults
    }

    func addressText() -> String {
        defaults.string(forKey: Self.addressKey) ?? ""
    }

    func tokenSaved() -> Bool {
        (try? keychain.loadMailboxToken()) != nil
    }

    func load() -> MailboxSetup? {
        guard let address = MailboxAddress(text: addressText()),
              let token = try? keychain.loadMailboxToken()
        else { return nil }
        return MailboxSetup(address: address, token: token)
    }

    /// An empty token field keeps the saved token, so the address can change on its own.
    func save(address text: String, token tokenText: String) -> MailboxSaveResult {
        guard let address = MailboxAddress(text: text) else { return .badAddress }
        do {
            if tokenText.isEmpty {
                guard tokenSaved() else { return .missingToken }
            } else {
                guard let token = MailboxToken(text: tokenText) else { return .missingToken }
                try keychain.saveMailboxToken(token)
            }
        } catch {
            return .failed
        }
        defaults.set(address.text, forKey: Self.addressKey)
        return .saved
    }

    func remove() -> MailboxSaveResult {
        do {
            try keychain.deleteMailboxToken()
        } catch {
            return .failed
        }
        defaults.removeObject(forKey: Self.addressKey)
        return .saved
    }
}
