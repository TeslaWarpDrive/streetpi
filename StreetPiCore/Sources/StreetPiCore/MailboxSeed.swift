import Foundation

/// Credentials carried only by the encrypted provisioned IPA. Construct through `ProvisionSeed.decode`.
public struct GatewaySeed: Sendable, Equatable, CustomStringConvertible, CustomDebugStringConvertible,
    CustomReflectable {
    public let url: URL
    public let clientID: String
    public let clientSecret: String

    public var description: String { "GatewaySeed(redacted)" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: []) }
}

public struct ProvisionSeed: Sendable, Equatable {
    public static let resourceName = "AwayProvision"
    public let mailbox: MailboxSetup?
    public let gateway: GatewaySeed?

    private struct MailboxWire: Decodable {
        let url: String
        let readToken: String
    }

    private struct GatewayWire: Decodable {
        let url: String
        let clientId: String
        let clientSecret: String
    }

    private struct Wire: Decodable {
        let version: Int
        let mailbox: MailboxWire?
        let gateway: GatewayWire?
        let mailboxURL: String?
        let readToken: String?
    }

    private struct Legacy: Decodable {
        let mailboxURL: String
        let readToken: String
    }

    public enum DecodeError: Error { case invalidSeed }

    /// Accepts v2 JSON, v1 JSON, and the original unversioned mailbox plist.
    /// Invalid input produces a value-free error, including malformed JSON containing credentials.
    public static func decode(_ data: Data) throws -> ProvisionSeed {
        do {
            if let legacy = try? PropertyListDecoder().decode(Legacy.self, from: data) {
                return try ProvisionSeed(mailboxURL: legacy.mailboxURL, token: legacy.readToken)
            }
            let wire = try JSONDecoder().decode(Wire.self, from: data)
            if wire.version == 1, let url = wire.mailboxURL, let token = wire.readToken {
                return try ProvisionSeed(mailboxURL: url, token: token)
            }
            guard wire.version == 2, wire.mailbox != nil || wire.gateway != nil else {
                throw DecodeError.invalidSeed
            }
            var mailbox: MailboxSetup?
            if let source = wire.mailbox {
                mailbox = try ProvisionSeed(mailboxURL: source.url, token: source.readToken).mailbox
            }
            var gateway: GatewaySeed?
            if let source = wire.gateway {
                let text = source.url.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.contains(where: \.isWhitespace),
                      !text.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
                      let parts = URLComponents(string: text),
                      parts.percentEncodedPath.isEmpty || parts.percentEncodedPath == "/",
                      parts.port.map({ (1...65535).contains($0) }) ?? true,
                      let address = MailboxAddress(text: text), let url = URL(string: address.text),
                      let clientID = MailboxToken(text: source.clientId),
                      let clientSecret = MailboxToken(text: source.clientSecret),
                      !clientID.secret.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
                      !clientSecret.secret.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
                else { throw DecodeError.invalidSeed }
                gateway = GatewaySeed(url: url, clientID: clientID.secret, clientSecret: clientSecret.secret)
            }
            return ProvisionSeed(mailbox: mailbox, gateway: gateway)
        } catch {
            throw DecodeError.invalidSeed
        }
    }

    private init(mailbox: MailboxSetup?, gateway: GatewaySeed?) {
        self.mailbox = mailbox
        self.gateway = gateway
    }

    private init(mailboxURL: String, token: String) throws {
        let text = mailboxURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.contains(where: \.isWhitespace),
              !text.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains),
              let parts = URLComponents(string: text),
              parts.port.map({ (1...65535).contains($0) }) ?? true,
              let address = MailboxAddress(text: text), let token = MailboxToken(text: token)
        else { throw DecodeError.invalidSeed }
        self.init(mailbox: MailboxSetup(address: address, token: token), gateway: nil)
    }

    public init?(plist: Data) {
        guard let seed = try? Self.decode(plist) else { return nil }
        self = seed
    }
}

public typealias MailboxSeed = ProvisionSeed

/// What to do with a bundled mailbox on launch.
public enum MailboxSeedStep: Sendable, Equatable {
    case nothing
    /// A mailbox is already saved. Remember that, so removing it later stays removed.
    case markHandled
    case seed(MailboxSetup)

    /// `handled` is true once this install has seeded, or has saved or removed a mailbox itself.
    public static func next(handled: Bool, configured: Bool, seed: ProvisionSeed?) -> MailboxSeedStep {
        if handled { return .nothing }
        if configured { return .markHandled }
        guard let mailbox = seed?.mailbox else { return .nothing }
        return .seed(mailbox)
    }
}
