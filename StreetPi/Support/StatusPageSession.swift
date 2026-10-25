import Foundation
import StreetPiCore

struct StatusPageURLSession: StatusPageTransport {
    var endpoint: StatusPageEndpoint

    func get(path: String) async throws -> StatusPageHTTPResponse {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            throw StatusPageProblem.offline
        }
        guard let url = endpoint.url(path: path) else {
            throw StatusPageProblem.notUnderstood
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let delegate = StatusPageRedirectionStop()
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        do {
            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            return StatusPageHTTPResponse(status: status, body: data)
        } catch let problem as StatusPageProblem {
            throw problem
        } catch {
            throw StatusPageProblem.offline
        }
    }
}

private final class StatusPageRedirectionStop: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        completionHandler(nil)
    }
}

final class StatusPageHold: @unchecked Sendable {
    private let lock = NSLock()
    private var board: HouseStatusBoard?

    func store(_ board: HouseStatusBoard) {
        lock.lock()
        self.board = board
        lock.unlock()
    }

    func take() -> HouseStatusBoard? {
        lock.lock()
        defer { lock.unlock() }
        return board
    }
}
