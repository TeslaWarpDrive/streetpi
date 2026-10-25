import Foundation
import StreetPiCore

struct StatusPageLiveTransport<Sender: LiveHTTPSending>: StatusPageTransport {
    var sender: Sender
    var base: URL

    func get(path: String) async throws -> StatusPageHTTPResponse {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            throw StatusPageProblem.offline
        }
        guard let url = LivePaths.url(base: base, path: path) else {
            throw StatusPageProblem.notUnderstood
        }
        do {
            let response = try await sender.get(url, headers: ["Accept": "application/json"])
            return StatusPageHTTPResponse(status: response.status, body: response.body)
        } catch let problem as StatusPageProblem {
            throw problem
        } catch is CancellationError {
            throw CancellationError()
        } catch LiveHTTPProblem.badAddress {
            throw StatusPageProblem.notUnderstood
        } catch {
            throw StatusPageProblem.offline
        }
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
