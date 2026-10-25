import Foundation
import StreetPiCore

struct PiMeterRefresh: Sendable {
    var endpoint: NetdataEndpoint

    func load() async -> Result<NetdataMeters, NetdataProblem> {
        guard endpoint.isLocalAgent else { return .failure(.notUnderstood) }
        let reader = NetdataReader(transport: NetdataURLSession(endpoint: endpoint))
        do {
            return .success(try await reader.load())
        } catch let problem as NetdataProblem {
            return .failure(problem)
        } catch {
            return .failure(.offline)
        }
    }
}

struct NetdataURLSession: NetdataTransport {
    var endpoint: NetdataEndpoint

    func get(_ path: String) async throws -> NetdataReply {
        guard let url = endpoint.url(for: path) else { throw NetdataProblem.notUnderstood }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 8
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let delegate = NetdataRedirectStop()
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        do {
            let (data, response) = try await session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if let host = response.url?.host?.lowercased(), Self.isCloud(host) {
                throw NetdataProblem.redirected
            }
            return NetdataReply(status: status, body: data)
        } catch let problem as NetdataProblem {
            throw problem
        } catch {
            throw NetdataProblem.offline
        }
    }

    private static func isCloud(_ host: String) -> Bool {
        host.contains("netdata.cloud") || host.contains("my-netdata.io")
    }
}

private final class NetdataRedirectStop: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
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
