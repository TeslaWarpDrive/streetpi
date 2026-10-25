import Foundation

/// Which house actions are sent to Pi-hole. Sign-out and refresh are not writes.
public enum PiholeActionRoute {
    public static func callsTheAPI(_ action: HouseholdAction) -> Bool {
        switch action {
        case .pauseAdBlocking, .resumeAdBlocking, .blockDomain, .allowDomain, .updateBlockLists:
            true
        case .refresh, .signOutOfAdBlocker:
            false
        }
    }
}

/// Sends one confirmed action and reads the Pi's answer. The session id is reused by the client.
public enum PiholeActions {
    public static func perform(
        _ action: HouseholdAction,
        client: PiholeClient,
        now: Date
    ) async throws -> ActionReceipt {
        switch action {
        case .pauseAdBlocking(let length):
            receipt(try await client.pause(seconds: length.seconds))
        case .resumeAdBlocking:
            receipt(try await client.resume())
        case .blockDomain:
            try await domainReceipt(action, client: client, detail: "Blocked", verb: "blocked")
        case .allowDomain:
            try await domainReceipt(action, client: client, detail: "Allowed", verb: "allowed")
        case .updateBlockLists:
            try await gravityReceipt(client: client, now: now)
        case .refresh, .signOutOfAdBlocker:
            throw PiholeProblem.notUnderstood
        }
    }

    private static func receipt(_ blocking: DNSBlocking) -> ActionReceipt {
        if blocking.enabled {
            return ActionReceipt(
                title: "Ad blocking is on.",
                detail: "The whole house is blocking ads.",
                blocking: blocking
            )
        }
        if let pause = blocking.pause {
            return ActionReceipt(
                title: "Ad blocking is paused.",
                detail: "It stays off for \(pause.title), then turns itself back on.",
                blocking: blocking
            )
        }
        return ActionReceipt(
            title: "Ad blocking is paused.",
            detail: "It turns itself back on.",
            blocking: blocking
        )
    }

    private static func domainReceipt(
        _ action: HouseholdAction,
        client: PiholeClient,
        detail: String,
        verb: String
    ) async throws -> ActionReceipt {
        let name: String
        switch action {
        case .blockDomain(let raw):
            name = try await client.block(domain: raw)
        case .allowDomain(let raw):
            name = try await client.allow(domain: raw)
        default:
            throw PiholeProblem.notUnderstood
        }
        return ActionReceipt(
            title: "\(detail).",
            detail: "\(name) is \(verb) for the whole house.",
            domainName: name,
            domainDetail: detail
        )
    }

    private static func gravityReceipt(client: PiholeClient, now: Date) async throws -> ActionReceipt {
        let report = try await client.updateGravity()
        return ActionReceipt(
            title: "Block lists updated.",
            detail: report.detail,
            listsUpdatedAt: now
        )
    }
}
