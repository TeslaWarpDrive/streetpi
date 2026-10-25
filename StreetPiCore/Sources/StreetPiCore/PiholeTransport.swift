import Foundation

public struct PiholeRequest: Sendable, Equatable, CustomStringConvertible {
    public var method: String
    public var path: String
    public var headers: [String: String]
    public var body: Data?
    /// Seconds to wait. Gravity can take a few minutes. Nil keeps the transport default.
    public var timeout: TimeInterval?

    public init(
        method: String,
        path: String,
        headers: [String: String],
        body: Data?,
        timeout: TimeInterval? = nil
    ) {
        self.method = method
        self.path = path
        self.headers = headers
        self.body = body
        self.timeout = timeout
    }

    /// Headers stay out of this text. The session id and the password are not logged.
    public var description: String {
        let note = path == "/api/auth" ? "redacted" : "\(body?.count ?? 0) bytes"
        return "\(method) \(path) body:\(note)"
    }
}

public struct PiholeResponse: Sendable, Equatable {
    public var status: Int
    public var body: Data

    public init(status: Int, body: Data) {
        self.status = status
        self.body = body
    }
}

public protocol PiholeTransport: Sendable {
    func send(_ request: PiholeRequest) async throws -> PiholeResponse
}

public final class ScriptedPiholeTransport: PiholeTransport, @unchecked Sendable {
    public struct Step: Sendable {
        public var status: Int
        public var body: Data
        public var failure: PiholeProblem?

        public init(status: Int, body: Data, failure: PiholeProblem? = nil) {
            self.status = status
            self.body = body
            self.failure = failure
        }

        public static func json(_ status: Int, _ text: String) -> Step {
            Step(status: status, body: Data(text.utf8))
        }

        public static func fail(_ problem: PiholeProblem) -> Step {
            Step(status: 0, body: Data(), failure: problem)
        }
    }

    private let lock = NSLock()
    private var steps: [Step]
    private var sentStorage: [PiholeRequest] = []

    public init(steps: [Step]) {
        self.steps = steps
    }

    public var sent: [PiholeRequest] {
        lock.lock()
        defer { lock.unlock() }
        return sentStorage
    }

    public func send(_ request: PiholeRequest) async throws -> PiholeResponse {
        guard let step = dequeue(request) else { throw PiholeProblem.notUnderstood }
        if let failure = step.failure {
            throw failure
        }
        return PiholeResponse(status: step.status, body: step.body)
    }

    private func dequeue(_ request: PiholeRequest) -> Step? {
        lock.lock()
        defer { lock.unlock() }
        sentStorage.append(request)
        guard !steps.isEmpty else { return nil }
        return steps.removeFirst()
    }
}
