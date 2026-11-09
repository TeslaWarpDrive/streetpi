import Foundation

/// The client id and secret typed in one Away connection section.
/// House Settings and the Settings tab each keep their own.
public struct AwaySectionDraft: Sendable, Equatable {
    public var clientID: String
    public var secret: String
    public var copy: AwayKeyCopy

    public init(clientID: String = "", secret: String = "", copy: AwayKeyCopy = AwayKeyCopy()) {
        self.clientID = clientID
        self.secret = secret
        self.copy = copy
    }

    public enum Outcome: Sendable, Equatable {
        /// The section called the save.
        case wrote(AwayGatewaySaveResult)
        /// A newer key is already stored, so this earlier pair was left.
        case kept
    }

    public mutating func acknowledge(stamp: Int) {
        copy.appeared(clientID: clientID, secret: secret, stamp: stamp)
    }

    public mutating func noteTyping(stamp: Int) {
        copy.typed(clientID: clientID, secret: secret, stamp: stamp)
    }

    /// An empty pair still saves, so the address can change on its own.
    /// A pair typed before a newer key does not.
    public mutating func save(
        address: String,
        replacing: Bool,
        stamp: Int,
        onSave: (String, String, String) -> AwayGatewaySaveResult
    ) -> Outcome {
        guard AwayKeyReplace.canSave(replacing: replacing, clientID: clientID, secret: secret) else {
            return .wrote(.missingCredentials)
        }
        let writingPair = clientID.isEmpty == false || secret.isEmpty == false
        if writingPair, copy.decision(clientID: clientID, secret: secret, stamp: stamp) == .keepSaved {
            return .kept
        }
        let result = onSave(address, clientID, secret)
        if result == .saved {
            clientID = ""
            secret = ""
        }
        return .wrote(result)
    }
}
