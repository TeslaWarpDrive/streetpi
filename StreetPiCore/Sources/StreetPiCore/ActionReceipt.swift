import Foundation

/// The Pi's answer after a write. The desk should follow this, not the tap that asked.
public struct ActionReceipt: Sendable, Equatable {
    public var title: String
    public var detail: String
    public var blocking: DNSBlocking?
    public var domainName: String?
    public var domainDetail: String?
    public var listsUpdatedAt: Date?
    public var pending: Bool

    public init(
        title: String,
        detail: String,
        blocking: DNSBlocking? = nil,
        domainName: String? = nil,
        domainDetail: String? = nil,
        listsUpdatedAt: Date? = nil,
        pending: Bool = false
    ) {
        self.title = title
        self.detail = detail
        self.blocking = blocking
        self.domainName = domainName
        self.domainDetail = domainDetail
        self.listsUpdatedAt = listsUpdatedAt
        self.pending = pending
    }
}

/// A line the ad blocker can show after a write. Failure copy comes from `PiholeProblem`.
public struct ActionNotice: Sendable, Equatable {
    public var title: String
    public var detail: String
    public var failed: Bool
    public var pending: Bool

    public init(title: String, detail: String, failed: Bool, pending: Bool = false) {
        self.title = title
        self.detail = detail
        self.failed = failed
        self.pending = pending
    }

    public init(problem: PiholeProblem) {
        self.init(title: problem.title, detail: problem.detail, failed: true)
    }

    public init(receipt: ActionReceipt) {
        self.init(title: receipt.title, detail: receipt.detail, failed: false, pending: receipt.pending)
    }
}
