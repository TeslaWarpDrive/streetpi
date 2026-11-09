import Foundation

/// What the house is about to do. The confirmation protects the action, whoever is holding the phone.
public enum HouseholdAction: Sendable, Equatable {
    case refresh
    case pauseAdBlocking(PauseLength)
    case resumeAdBlocking
    case blockDomain(named: String)
    case allowDomain(named: String)
    case updateBlockLists
    case signOutOfAdBlocker
}

public enum Confirmation: Sendable, Equatable {
    case notRequired
    case explain(String)
    case explainAndUseFaceID(String)

    public var explanation: String? {
        switch self {
        case .notRequired:
            nil
        case .explain(let text), .explainAndUseFaceID(let text):
            text
        }
    }

    public var requiresFaceID: Bool {
        if case .explainAndUseFaceID = self {
            return true
        }
        return false
    }
}

/// Sent, refused, or still waiting on Face ID. Ask again after the prompt. The road can change.
public enum ConfirmStep: Sendable, Equatable {
    case allow
    case refuse
    case wait
}

/// What Face ID just did. Cancel and failure are not a pass. Deny leaves the sheet up.
public enum FaceIDPrompt: Sendable, Equatable {
    case notAsked
    case passed
    case denied
    case cancelled
    case failed
}

public enum ActionPolicy {
    /// Refuse when this road will not take the action. A pass allows it.
    /// Deny, cancel, and failure wait, so the write is not sent.
    public static func confirmStep(
        _ action: HouseholdAction,
        mode: ConnectionMode,
        faceID: FaceIDPrompt
    ) -> ConfirmStep {
        guard mode.allows(action) else { return .refuse }
        guard confirmation(for: action).requiresFaceID else { return .allow }
        if faceID == .passed { return .allow }
        return .wait
    }

    public static func confirmation(for action: HouseholdAction) -> Confirmation {
        switch action {
        case .refresh:
            return .notRequired
        case .signOutOfAdBlocker:
            return .explain(plainCopy(action))
        case .pauseAdBlocking, .resumeAdBlocking, .blockDomain, .allowDomain, .updateBlockLists:
            return .explainAndUseFaceID(plainCopy(action))
        }
    }

    private static func plainCopy(_ action: HouseholdAction) -> String {
        switch action {
        case .pauseAdBlocking(let length):
            return pauseCopy(length)
        case .resumeAdBlocking:
            return "Ad blocking will turn back on for the whole house now."
        case .blockDomain(let name):
            return "\(name) will be blocked for the whole house."
        case .allowDomain(let name):
            return "\(name) will be allowed for the whole house."
        case .updateBlockLists:
            return """
            Block lists will update for the whole house. This can take a minute. \
            Ads stay blocked while it runs.
            """
        case .signOutOfAdBlocker:
            return "This phone will sign out. The password stays on this phone, and ad blocking stays as it is."
        case .refresh:
            return "This will change the house."
        }
    }

    private static func pauseCopy(_ length: PauseLength) -> String {
        """
        Ad blocking will pause for the whole house for \(length.title). \
        It turns itself back on. Ads will load until then.
        """
    }
}
