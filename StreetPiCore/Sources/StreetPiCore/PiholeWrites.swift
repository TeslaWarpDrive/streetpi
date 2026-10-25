import Foundation

public enum FTLSessionPolicy {
    public static let maximumSessions = 16
    public static let validitySeconds = 1_800
    public static let sidHeader = "X-FTL-SID"
}

public enum PiholeProblem: Error, Sendable, Equatable {
    case needsPassword
    case refused
    case offline
    case needsSignIn
    case notUnderstood
    case invalidDomain
    case invalidPause
    case notSetUp
    case dnsOff
    case certificateChanged
    case pinKept

    public var title: String {
        switch self {
        case .refused:
            "The Pi said no."
        case .offline:
            "The Pi is not answering."
        case .needsPassword:
            "Save the app password first."
        case .needsSignIn:
            "Sign in again."
        case .invalidDomain:
            "That name does not look right."
        case .invalidPause:
            "Choose how long to pause."
        case .notUnderstood:
            "The Pi sent something this phone could not read."
        case .notSetUp:
            "The ad blocker is not set up."
        case .dnsOff:
            "The ad blocker is not running."
        case .certificateChanged:
            "The ad blocker's certificate changed."
        case .pinKept:
            "The saved security pin is still in use."
        }
    }

    public var detail: String {
        switch self {
        case .refused:
            "The Pi will not do that from this phone. Nothing was changed."
        case .offline:
            "This phone can't see the Pi right now. Nothing was changed. Raspberry Pi Stats will try again on its own."
        case .needsPassword:
            "Enter the app password once. It stays on this phone."
        case .needsSignIn:
            "The sign-in expired. This phone will ask again."
        case .invalidDomain:
            "Use a name like news.example.test."
        case .invalidPause:
            "Pick 30 seconds, 5 minutes, 30 minutes, or a custom length up to a day."
        case .notUnderstood:
            "Nothing was changed."
        case .notSetUp:
            "Save the app password on this phone, then Raspberry Pi Stats can read the ad blocker."
        case .dnsOff:
            "The Pi answered, and name lookup is off. Nothing was changed."
        case .certificateChanged:
            PiholePin.question
        case .pinKept:
            "This phone did not trust the new certificate. You can change the pin in Settings."
        }
    }
}

public enum DomainName {
    public static func normalized(_ raw: String) -> String? {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard (1...253).contains(name.count) else { return nil }
        guard name.contains("."), !name.hasPrefix("."), !name.hasSuffix(".") else { return nil }
        guard !name.contains("..") else { return nil }
        let allowed = CharacterSet.lowercaseLetters
            .union(.decimalDigits)
            .union(CharacterSet(charactersIn: ".-"))
        guard name.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        return name
    }
}

public enum PiholeWrites {
    public static func pause(seconds: Int) -> PiholeRequest? {
        guard PauseLength(seconds: seconds) != nil else { return nil }
        let body = Data("{\"blocking\":false,\"timer\":\(seconds)}".utf8)
        return PiholeRequest(method: "POST", path: "/api/dns/blocking", headers: [:], body: body)
    }

    public static func resume() -> PiholeRequest {
        let body = Data("{\"blocking\":true,\"timer\":null}".utf8)
        return PiholeRequest(method: "POST", path: "/api/dns/blocking", headers: [:], body: body)
    }

    public static func block(domain: String) -> PiholeRequest? {
        domainRequest(domain, path: "/api/domains/deny/exact")
    }

    public static func allow(domain: String) -> PiholeRequest? {
        domainRequest(domain, path: "/api/domains/allow/exact")
    }

    private static func domainRequest(_ domain: String, path: String) -> PiholeRequest? {
        guard let name = DomainName.normalized(domain) else { return nil }
        let body = Data("{\"domain\":\"\(name)\",\"enabled\":true}".utf8)
        return PiholeRequest(method: "POST", path: path, headers: [:], body: body)
    }
}
