import Foundation

/// A mailbox the build carries, so nobody has to type it on a phone. Only the provisioned IPA has one.
/// Its description comes from `MailboxSetup`, and the token inside never prints.
public struct MailboxSeed: Sendable, Equatable {
    /// `AwayProvision.plist`, added to the app by `scripts/seal-provisioned-ipa.sh`.
    public static let resourceName = "AwayProvision"

    private struct Wire: Decodable {
        var mailboxURL: String
        var readToken: String
    }

    public let setup: MailboxSetup

    public init?(plist: Data) {
        guard let wire = try? PropertyListDecoder().decode(Wire.self, from: plist),
              let address = MailboxAddress(text: wire.mailboxURL),
              let token = MailboxToken(text: wire.readToken)
        else { return nil }
        setup = MailboxSetup(address: address, token: token)
    }
}

/// What to do with a bundled mailbox on launch.
public enum MailboxSeedStep: Sendable, Equatable {
    case nothing
    /// A mailbox is already saved. Remember that, so removing it later stays removed.
    case markHandled
    case seed(MailboxSetup)

    /// `handled` is true once this install has seeded, or has saved or removed a mailbox itself.
    public static func next(handled: Bool, configured: Bool, seed: MailboxSeed?) -> MailboxSeedStep {
        if handled { return .nothing }
        if configured { return .markHandled }
        guard let seed else { return .nothing }
        return .seed(seed.setup)
    }
}
