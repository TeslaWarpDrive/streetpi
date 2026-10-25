import Foundation

/// What a gravity run told this phone. The text is plain English, never the raw log.
public struct GravityReport: Sendable, Equatable {
    public var domainCount: Int?
    public var detail: String

    public init(domainCount: Int?, detail: String) {
        self.domainCount = domainCount
        self.detail = detail
    }
}
