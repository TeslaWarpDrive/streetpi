import Foundation
import StreetPiCore

/// Local Netdata agent on the LAN. No login, no cloud host, and redirects count as a failed read.
struct NetdataURLSessionTransport: Sendable {
    func get(pathAndQuery: String) async throws -> AgentHTTPResult {
        guard !FixtureGate.isFixtureRun else { throw NetdataProblem.offline }
        let base = LiveHostStore().load().netdata
        guard let url = NetdataEndpoint.joining(base: base, pathAndQuery: pathAndQuery) else {
            throw NetdataProblem.notUnderstood
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        urlRequest.timeoutInterval = 8
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        let delegate = NetdataRedirectDelegate()
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        do {
            let (data, response) = try await session.data(for: urlRequest)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let redirected = delegate.redirected || (300...399).contains(status)
            return AgentHTTPResult(status: status, body: data, redirected: redirected)
        } catch let problem as NetdataProblem {
            throw problem
        } catch {
            throw NetdataProblem.offline
        }
    }
}

private final class NetdataRedirectDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var sawRedirect = false

    var redirected: Bool {
        lock.lock()
        defer { lock.unlock() }
        return sawRedirect
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        lock.lock()
        sawRedirect = true
        lock.unlock()
        completionHandler(nil)
    }
}
