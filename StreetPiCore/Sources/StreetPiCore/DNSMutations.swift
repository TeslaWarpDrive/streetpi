import Foundation

extension DNSDesk {
    public func applying(_ action: HouseholdAction) -> DNSDesk {
        var copy = self
        switch action {
        case .pauseAdBlocking(let length):
            copy.blocking = DNSBlocking(enabled: false, pause: length)
        case .resumeAdBlocking:
            copy.blocking = DNSBlocking(enabled: true)
        case .blockDomain(let name):
            copy.upsert(name, detail: "Blocked")
        case .allowDomain(let name):
            copy.upsert(name, detail: "Allowed")
        case .updateBlockLists:
            copy.listsUpdatedAt = .streetFixtureNow
        case .refresh, .signOutOfAdBlocker:
            break
        }
        return copy
    }

    /// Applies what the Pi reported. A failed call must not use this.
    public func adopting(_ receipt: ActionReceipt) -> DNSDesk {
        var copy = self
        if let blocking = receipt.blocking {
            copy.blocking = blocking
        }
        if let name = receipt.domainName, let detail = receipt.domainDetail {
            copy.upsert(name, detail: detail)
        }
        if let updated = receipt.listsUpdatedAt {
            copy.listsUpdatedAt = updated
        }
        return copy
    }

    private mutating func upsert(_ name: String, detail: String) {
        if let index = domains.firstIndex(where: { $0.name == name }) {
            domains[index].detail = detail
        } else {
            domains.append(NamedRow(id: name, name: name, detail: detail))
        }
    }
}
