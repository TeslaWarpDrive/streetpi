import Foundation

/// What saving or removing a gateway key did. The note is the line Settings shows.
public enum AwayGatewaySaveResult: Sendable, Equatable {
    case saved
    case badAddress
    case missingCredentials
    case failed

    public var note: String {
        switch self {
        case .saved:
            "Saved."
        case .badAddress:
            "Use the gateway's https address, with nothing after the name."
        case .missingCredentials:
            "Paste the client id and the secret, with no spaces."
        case .failed:
            "That could not be saved on this phone."
        }
    }
}

/// A saved gateway key stays masked until Replace key. The secret is never copied into the fields.
public enum AwayKeyReplace: Sendable {
    public static func showsFields(saved: Bool, replacing: Bool) -> Bool {
        saved == false || replacing
    }

    /// An empty replacement would keep the saved secret, so both new values are required.
    public static func canSave(replacing: Bool, clientID: String, secret: String) -> Bool {
        guard replacing else { return true }
        let id = clientID.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = secret.trimmingCharacters(in: .whitespacesAndNewlines)
        return id.isEmpty == false && key.isEmpty == false
    }
}

/// What the rejected-key card has typed so far. Settings holds it, so a probe that clears the message
/// takes the message away and leaves the text. It stays in memory and goes when the save does.
public struct AwayKeyDraft: Sendable, Equatable {
    public static let savedLine = "New key saved."

    public var clientID: String
    public var secret: String
    public var note: String
    public var saved: Bool
    /// The save this draft was typed against. The other Settings screen may have saved a newer key.
    public var copy: AwayKeyCopy

    public init(
        clientID: String = "",
        secret: String = "",
        note: String = "",
        saved: Bool = false,
        copy: AwayKeyCopy = AwayKeyCopy()
    ) {
        self.clientID = clientID
        self.secret = secret
        self.note = note
        self.saved = saved
        self.copy = copy
    }

    private var hasText: Bool {
        clientID.isEmpty == false || secret.isEmpty == false
    }

    public func showsForm(notice: String?) -> Bool {
        notice != nil || hasText
    }

    public func showsConfirmation(notice: String?) -> Bool {
        saved && showsForm(notice: notice) == false
    }

    /// A rejection after a save means the new key did not work, so "saved" must not come back later.
    /// A note about a form that has gone must not come back with the next one either.
    public mutating func settle(notice: String?) {
        if notice != nil { saved = false }
        if showsForm(notice: notice) == false { note = "" }
    }

    public mutating func acknowledge(stamp: Int) {
        copy.appeared(clientID: clientID, secret: secret, stamp: stamp)
    }

    public mutating func noteTyping(stamp: Int) {
        copy.typed(clientID: clientID, secret: secret, stamp: stamp)
    }

    /// Both new values are required. A failed save keeps what was typed.
    /// A saved key replaces the draft, then the basis catches up to the stamp so the next pair is recorded.
    public mutating func save(
        address: String,
        stamp: () -> Int = { 0 },
        onSave: (String, String, String) -> AwayGatewaySaveResult
    ) {
        guard AwayKeyReplace.canSave(replacing: true, clientID: clientID, secret: secret) else {
            note = AwayGatewaySaveResult.missingCredentials.note
            return
        }
        let result = onSave(address, clientID, secret)
        guard result == .saved else {
            note = result.note
            return
        }
        self = AwayKeyDraft(saved: true)
        acknowledge(stamp: stamp())
    }
}
