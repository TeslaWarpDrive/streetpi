import Foundation
import StreetPiCore

/// Reads the mailbox over default TLS. Tests never open this socket.
/// The session keeps no cache or cookies, and a redirect is refused so the token only goes to the saved host.
struct MailboxURLSession: MailboxTransport {
    private static let timeout: TimeInterval = 5

    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = Self.timeout
        configuration.timeoutIntervalForResource = Self.timeout
        session = URLSession(configuration: configuration, delegate: RedirectRefusal(), delegateQueue: nil)
    }

    func get(_ url: URL, token: MailboxToken) async throws -> MailboxReply {
        guard LiveReaderGate.opensSockets else { throw MailboxProblem.offline }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token.secret)", forHTTPHeaderField: "Authorization")
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw MailboxProblem.offline }
            return MailboxReply(status: http.statusCode, body: data)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        }
    }
}

private final class RedirectRefusal: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}
