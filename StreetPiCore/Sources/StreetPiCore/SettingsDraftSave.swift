import Foundation

/// House Settings and the Settings tab each keep a pin and an away-key draft.
/// `basis` is the save this screen copied. `current` is the save stored now.
/// `draftIsCopy` is true when this screen would write that copied value, not a later edit.
public enum SettingsDraftSave {
    public enum Decision: Sendable, Equatable {
        /// Write this screen's draft.
        case write
        /// The stored value is newer. Leave it.
        case keepSaved
    }

    public static let keptPinNote = "The saved pin is newer, so this copy was left."
    public static let keptKeyNote = "The saved key is newer, so this copy was left."

    public static func decide(basis: String, current: String, draftIsCopy: Bool) -> Decision {
        let olderCopy = current != basis && draftIsCopy
        if olderCopy {
            // Today the older copy still replaces the newer save.
            return .write
        }
        return .write
    }

    /// Pin fields are compared with surrounding space removed.
    public static func decision(seen: String, draft: String, saved: String) -> Decision {
        let seenPin = normalize(seen)
        let draftPin = normalize(draft)
        let savedPin = normalize(saved)
        return decide(basis: seenPin, current: savedPin, draftIsCopy: draftPin == seenPin)
    }

    /// The pin that remains stored.
    public static func pin(seen: String, draft: String, saved: String) -> String {
        let draftPin = normalize(draft)
        let savedPin = normalize(saved)
        switch decision(seen: seen, draft: draft, saved: saved) {
        case .keepSaved:
            return savedPin
        case .write:
            return draftPin
        }
    }

    private static func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// The away-key draft on one Settings screen, compared with the shared save count.
public struct AwayKeyCopy: Sendable, Equatable {
    public var basis: Int
    /// The client id this screen had copied while `basis` was still the stored save.
    public var basisClientID: String
    /// The secret this screen had copied while `basis` was still the stored save.
    public var basisSecret: String

    public init(basis: Int = 0, basisClientID: String = "", basisSecret: String = "") {
        self.basis = basis
        self.basisClientID = basisClientID
        self.basisSecret = basisSecret
    }

    /// An empty draft catches up to the save count. Typed text stays with the count it was written against.
    public mutating func appeared(clientID: String, secret: String, stamp: Int) {
        guard clientID.isEmpty, secret.isEmpty else { return }
        basis = stamp
        basisClientID = ""
        basisSecret = ""
    }

    /// Typing while the save count is unchanged keeps this draft as the copy of that save.
    public mutating func typed(clientID: String, secret: String, stamp: Int) {
        guard stamp == basis else { return }
        basisClientID = clientID
        basisSecret = secret
    }

    public func decision(clientID: String, secret: String, stamp: Int) -> SettingsDraftSave.Decision {
        let draftIsCopy = clientID == basisClientID && secret == basisSecret
        return SettingsDraftSave.decide(
            basis: String(basis),
            current: String(stamp),
            draftIsCopy: draftIsCopy
        )
    }

    public func kept(
        clientID: String,
        secret: String,
        stamp: Int,
        savedClientID: String,
        savedSecret: String
    ) -> (clientID: String, secret: String) {
        switch decision(clientID: clientID, secret: secret, stamp: stamp) {
        case .keepSaved:
            return (savedClientID, savedSecret)
        case .write:
            return (clientID, secret)
        }
    }
}
