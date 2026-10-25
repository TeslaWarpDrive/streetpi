import Foundation
import Security
import StreetPiCore

/// Opens a socket only outside tests, so CI never calls the Pi.
enum LiveReaderGate {
    static var opensSockets: Bool {
        let environment = ProcessInfo.processInfo.environment
        if environment["XCTestConfigurationFilePath"] != nil {
            return false
        }
        if environment["STREETPI_LIVE_READER"] == "off" {
            return false
        }
        return true
    }
}

final class PresentedPinBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: String?

    func presented() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    func record(_ pin: String) {
        lock.lock()
        value = pin
        lock.unlock()
    }
}

final class DNSSessionHold {
    var client: PiholeClient?
    var http: LiveHTTPClient?
    var endpoint: PiholeEndpoint?
    var pin: String?
    var presented: PresentedPinBox?
    var signedIn = false
}

/// Live transport. The session id and the app password are never written to a log.
struct PiholeURLSessionTransport: PiholeTransport {
    var http: LiveHTTPClient
    var endpoint: PiholeEndpoint
    var sessions: KeychainSession
    var presented: PresentedPinBox

    func send(_ request: PiholeRequest) async throws -> PiholeResponse {
        guard LiveReaderGate.opensSockets else {
            throw PiholeProblem.offline
        }
        guard let url = endpoint.url(pathAndQuery: request.path) else {
            throw PiholeProblem.notUnderstood
        }
        if request.method == "DELETE", request.path == "/api/auth" {
            try? sessions.deleteSessionID()
        }
        do {
            let response = try await dispatch(request, url: url)
            remember(request, response: response)
            return PiholeResponse(status: response.status, body: response.body)
        } catch let problem as LiveHTTPProblem {
            switch problem {
            case .badAddress:
                throw PiholeProblem.notUnderstood
            case .unreachable:
                throw PiholeProblem.offline
            case .untrusted:
                try await refuseUntrusted()
            }
        } catch let problem as PiholeProblem {
            throw problem
        } catch {
            throw PiholeProblem.offline
        }
    }

    private func dispatch(_ request: PiholeRequest, url: URL) async throws -> LiveHTTPResponse {
        var headers = request.headers
        headers["Accept"] = "application/json"
        if request.body != nil {
            headers["Content-Type"] = "application/json"
        }
        switch request.method {
        case "GET":
            return try await http.get(url, headers: headers)
        case "POST":
            return try await http.post(url, headers: headers, body: request.body)
        case "DELETE":
            return try await http.delete(url, headers: headers)
        default:
            throw PiholeProblem.notUnderstood
        }
    }

    private func refuseUntrusted() async throws -> Never {
        let expected = http.pinner.trustedPin()
        if let pin = await PresentedCertificate.pin(host: endpoint.host),
           PiholePin.matches(presented: pin, expected: expected) == false {
            presented.record(pin)
            throw PiholeProblem.certificateChanged
        }
        throw PiholeProblem.offline
    }

    private func remember(_ request: PiholeRequest, response: LiveHTTPResponse) {
        if request.method == "POST", request.path == "/api/auth", (200...299).contains(response.status),
           let sid = Self.sessionID(in: response.body) {
            try? sessions.saveSessionID(sid)
            return
        }
        if let sid = request.headers[FTLSessionPolicy.sidHeader], sid.isEmpty == false {
            try? sessions.saveSessionID(sid)
        }
    }

    private static func sessionID(in body: Data) -> String? {
        guard let wire = try? JSONDecoder().decode(AuthSessionWire.self, from: body) else { return nil }
        let sid = wire.session.sid.trimmingCharacters(in: .whitespacesAndNewlines)
        return sid.isEmpty ? nil : sid
    }
}

private struct AuthSessionWire: Decodable {
    struct Session: Decodable {
        var sid: String
    }

    var session: Session
}

/// Reads the leaf pin during the handshake and does not send the app password.
private enum PresentedCertificate {
    static func pin(host: String) async -> String? {
        guard LiveReaderGate.opensSockets, let url = URL(string: "https://\(host)/api/info/login") else {
            return nil
        }
        let catcher = PinCatcher()
        let session = URLSession(configuration: .ephemeral, delegate: catcher, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 12
        _ = try? await session.data(for: request)
        return catcher.pin
    }
}

private final class PinCatcher: NSObject, URLSessionDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var found: String?

    var pin: String? {
        lock.lock()
        defer { lock.unlock() }
        return found
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        _ = session
        let space = challenge.protectionSpace
        guard space.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = space.serverTrust,
              let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
              let leaf = chain.first,
              let pin = CertificatePinner.spkiSHA256Base64(of: leaf)
        else {
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        lock.lock()
        found = pin
        lock.unlock()
        completionHandler(.cancelAuthenticationChallenge, nil)
    }
}

enum AdBlockerSecrets {
    static func password(in store: any SecretStoring) -> String {
        (try? KeychainSession(store: store).loadAppPassword()) ?? ""
    }
}
