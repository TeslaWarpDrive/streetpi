import Foundation

/// House addresses. Settings can replace each one; these are the starting values.
enum LiveHouse {
    static let host = "192.168.1.78"
    static let piholeAddress = "https://192.168.1.78/api"
    static let netdataAddress = "http://192.168.1.78:19999"
    static let uptimeKumaAddress = "http://192.168.1.78:3001"
    /// SPKI SHA-256 of the Pi-hole certificate, standard base64.
    static let spkiSHA256 = "lDT1PbNsR197fgVM+1rlXJMbTjMNg7forqemXVQX/7Y="
}

struct LiveEndpoints: Equatable, Sendable {
    var pihole: URL
    var netdata: URL
    var uptimeKuma: URL

    static let house = LiveEndpoints(
        pihole: LiveAddress.parse(LiveHouse.piholeAddress),
        netdata: LiveAddress.parse(LiveHouse.netdataAddress),
        uptimeKuma: LiveAddress.parse(LiveHouse.uptimeKumaAddress)
    )

    var piholeHost: String {
        pihole.host ?? LiveHouse.host
    }
}

enum LiveHostError: Error, Equatable {
    case invalidAddress
    case invalidPin
}

/// Settings reads and writes these keys. Nothing here opens a connection.
struct LiveHostStore: Sendable {
    static let piholeKey = "settings.live.pihole"
    static let netdataKey = "settings.live.netdata"
    static let uptimeKumaKey = "settings.live.uptimeKuma"
    static let pinKey = "settings.live.spkiSha256"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> LiveEndpoints {
        LiveEndpoints(
            pihole: validated(defaults.string(forKey: Self.piholeKey), schemes: ["https"])
                ?? LiveEndpoints.house.pihole,
            netdata: validated(defaults.string(forKey: Self.netdataKey), schemes: ["http", "https"])
                ?? LiveEndpoints.house.netdata,
            uptimeKuma: validated(defaults.string(forKey: Self.uptimeKumaKey), schemes: ["http", "https"])
                ?? LiveEndpoints.house.uptimeKuma
        )
    }

    func piholeText() -> String {
        text(Self.piholeKey, fallback: LiveEndpoints.house.pihole.absoluteString)
    }

    func netdataText() -> String {
        text(Self.netdataKey, fallback: LiveEndpoints.house.netdata.absoluteString)
    }

    func uptimeKumaText() -> String {
        text(Self.uptimeKumaKey, fallback: LiveEndpoints.house.uptimeKuma.absoluteString)
    }

    func save(pihole: String, netdata: String, uptimeKuma: String) throws {
        guard let piholeURL = validated(pihole, schemes: ["https"]),
              let netdataURL = validated(netdata, schemes: ["http", "https"]),
              let kumaURL = validated(uptimeKuma, schemes: ["http", "https"])
        else {
            throw LiveHostError.invalidAddress
        }
        defaults.set(piholeURL.absoluteString, forKey: Self.piholeKey)
        defaults.set(netdataURL.absoluteString, forKey: Self.netdataKey)
        defaults.set(kumaURL.absoluteString, forKey: Self.uptimeKumaKey)
    }

    /// Stored pin, or nil when Settings is still on the shipped pin.
    func loadPin() -> String? {
        let stored = defaults.string(forKey: Self.pinKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let stored, !stored.isEmpty else { return nil }
        return stored
    }

    func pinText() -> String {
        loadPin() ?? LiveHouse.spkiSHA256
    }

    func savePin(_ pin: String) throws {
        let trimmed = pin.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let digest = Data(base64Encoded: trimmed), digest.count == 32 else {
            throw LiveHostError.invalidPin
        }
        defaults.set(trimmed, forKey: Self.pinKey)
    }

    func clearPin() {
        defaults.removeObject(forKey: Self.pinKey)
    }

    private func text(_ key: String, fallback: String) -> String {
        let stored = defaults.string(forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let stored, !stored.isEmpty else { return fallback }
        return stored
    }

    private func validated(_ text: String?, schemes: Set<String>) -> URL? {
        guard let text else { return nil }
        return LiveAddress.validated(text, schemes: schemes)
    }
}

enum LivePaths {
    static func url(base: URL, path: String) -> URL? {
        let root = base.absoluteString.hasSuffix("/")
            ? String(base.absoluteString.dropLast())
            : base.absoluteString
        let tail = path.hasPrefix("/") ? String(path.dropFirst()) : path
        guard !tail.isEmpty else { return base }
        return URL(string: root + "/" + tail)
    }
}

struct LiveHTTPResponse: Sendable, Equatable, CustomStringConvertible {
    var status: Int
    var headers: [String: String]
    var body: Data

    var description: String {
        "LiveHTTPResponse(status: \(status), bytes: \(body.count))"
    }
}

enum LiveHTTPProblem: Error, Sendable, Equatable {
    case badAddress
    case untrusted
    case unreachable
}

protocol LiveHTTPSending: Sendable {
    func get(_ url: URL, headers: [String: String]) async throws -> LiveHTTPResponse
    func post(_ url: URL, headers: [String: String], body: Data?) async throws -> LiveHTTPResponse
    func delete(_ url: URL, headers: [String: String]) async throws -> LiveHTTPResponse
}

/// The one URLSession stack. A request is the only thing that opens a connection.
final class LiveHTTPClient: LiveHTTPSending, @unchecked Sendable {
    let pinner: CertificatePinner
    private let session: URLSession

    init(pinner: CertificatePinner, configuration: URLSessionConfiguration) {
        self.pinner = pinner
        session = URLSession(configuration: configuration, delegate: pinner, delegateQueue: nil)
    }

    convenience init(
        store: LiveHostStore = LiveHostStore(),
        configuration: URLSessionConfiguration = LiveHTTPClient.sessionConfiguration()
    ) {
        let endpoints = store.load()
        let pinner = CertificatePinner(
            spkiSHA256Base64: store.loadPin() ?? CertificatePinner.defaultSPKISha256,
            host: endpoints.piholeHost
        )
        self.init(pinner: pinner, configuration: configuration)
    }

    deinit {
        session.finishTasksAndInvalidate()
    }

    static func sessionConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.waitsForConnectivity = false
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        return configuration
    }

    func apply(_ store: LiveHostStore) {
        let endpoints = store.load()
        pinner.replaceHost(endpoints.piholeHost)
        pinner.replacePin(store.loadPin() ?? CertificatePinner.defaultSPKISha256)
    }

    func get(_ url: URL, headers: [String: String] = [:]) async throws -> LiveHTTPResponse {
        try await send(method: "GET", url: url, headers: headers, body: nil)
    }

    func post(
        _ url: URL,
        headers: [String: String] = [:],
        body: Data? = nil
    ) async throws -> LiveHTTPResponse {
        try await send(method: "POST", url: url, headers: headers, body: body)
    }

    func delete(_ url: URL, headers: [String: String] = [:]) async throws -> LiveHTTPResponse {
        try await send(method: "DELETE", url: url, headers: headers, body: nil)
    }

    private func send(
        method: String,
        url: URL,
        headers: [String: String],
        body: Data?
    ) async throws -> LiveHTTPResponse {
        guard LiveAddress.isSafe(url) else { throw LiveHTTPProblem.badAddress }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        for (field, value) in headers {
            request.setValue(value, forHTTPHeaderField: field)
        }
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw LiveHTTPProblem.unreachable }
            return LiveHTTPResponse(status: http.statusCode, headers: Self.headerMap(http), body: data)
        } catch let problem as LiveHTTPProblem {
            throw problem
        } catch is CancellationError {
            throw CancellationError()
        } catch let urlError as URLError {
            throw Self.problem(from: urlError)
        } catch {
            throw LiveHTTPProblem.unreachable
        }
    }

    private static func headerMap(_ response: HTTPURLResponse) -> [String: String] {
        var mapped: [String: String] = [:]
        for (field, value) in response.allHeaderFields {
            guard let name = field as? String, let text = value as? String else { continue }
            mapped[name] = text
        }
        return mapped
    }

    private static func problem(from error: URLError) -> Error {
        if error.code == .cancelled, Task.isCancelled {
            return CancellationError()
        }
        switch error.code {
        case .cancelled, .serverCertificateUntrusted, .serverCertificateHasBadDate,
             .serverCertificateHasUnknownRoot, .serverCertificateNotYetValid,
             .secureConnectionFailed, .clientCertificateRejected:
            return LiveHTTPProblem.untrusted
        default:
            return LiveHTTPProblem.unreachable
        }
    }
}

enum LiveAddress {
    static func parse(_ text: String) -> URL {
        if let url = URL(string: text) {
            return url
        }
        preconditionFailure("Expected a house address")
    }

    static func validated(_ text: String, schemes: Set<String>) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), isSafe(url), let scheme = url.scheme?.lowercased() else {
            return nil
        }
        guard schemes.contains(scheme) else { return nil }
        return url
    }

    static func isSafe(_ url: URL) -> Bool {
        guard url.user == nil, url.password == nil, let host = url.host, !host.isEmpty else { return false }
        return true
    }
}
