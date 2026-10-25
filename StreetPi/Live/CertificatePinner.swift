import CryptoKit
import Foundation
import Security

/// URLSession trust check for one host. The pin can be replaced while the app is open.
final class CertificatePinner: NSObject, URLSessionDelegate, @unchecked Sendable {
    static let defaultSPKISha256 = LiveHouse.spkiSHA256
    static let defaultHost = LiveHouse.host
    static let changedCertificatePrompt = "The ad blocker's security certificate changed, trust the new one?"

    private let lock = NSLock()
    private var pin: String
    private var host: String

    init(spkiSHA256Base64: String = CertificatePinner.defaultSPKISha256, host: String = CertificatePinner.defaultHost) {
        pin = Self.normalize(spkiSHA256Base64)
        self.host = host
        super.init()
    }

    func replacePin(_ spkiSHA256Base64: String) {
        let next = Self.normalize(spkiSHA256Base64)
        lock.lock()
        pin = next
        lock.unlock()
    }

    func replaceHost(_ host: String) {
        lock.lock()
        self.host = host
        lock.unlock()
    }

    func trustedPin() -> String {
        snapshot().pin
    }

    func trustedHost() -> String {
        snapshot().host
    }

    func accepts(certificate: SecCertificate, host: String) -> Bool {
        let current = snapshot()
        guard Self.hostsMatch(host, current.host), let presented = Self.spkiSHA256Base64(of: certificate) else {
            return false
        }
        return Self.pinsMatch(presented, current.pin)
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        _ = session
        let space = challenge.protectionSpace
        guard space.authenticationMethod == NSURLAuthenticationMethodServerTrust, let trust = space.serverTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        let current = snapshot()
        guard Self.hostsMatch(space.host, current.host),
              let leaf = Self.leafCertificate(in: trust),
              let presented = Self.spkiSHA256Base64(of: leaf),
              Self.pinsMatch(presented, current.pin)
        else {
            if Self.hostsMatch(space.host, current.host) {
                completionHandler(.cancelAuthenticationChallenge, nil)
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
            return
        }
        completionHandler(.useCredential, URLCredential(trust: trust))
    }

    static func spkiSHA256Base64(of certificate: SecCertificate) -> String? {
        guard let key = SecCertificateCopyKey(certificate) else { return nil }
        var error: Unmanaged<CFError>?
        guard let external = SecKeyCopyExternalRepresentation(key, &error) as Data? else {
            _ = error?.takeRetainedValue()
            return nil
        }
        guard let spki = subjectPublicKeyInfo(key: key, point: external) else { return nil }
        let digest = SHA256.hash(data: spki)
        return Data(digest).base64EncodedString()
    }

    private struct Snapshot {
        var pin: String
        var host: String
    }

    private func snapshot() -> Snapshot {
        lock.lock()
        defer { lock.unlock() }
        return Snapshot(pin: pin, host: host)
    }

    private static func normalize(_ pin: String) -> String {
        var value = pin.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = "sha256/"
        if value.lowercased().hasPrefix(prefix) {
            value = String(value.dropFirst(prefix.count))
        }
        return value
    }

    private static func hostsMatch(_ presented: String, _ pinned: String) -> Bool {
        let left = normalizedHost(presented)
        let right = normalizedHost(pinned)
        guard !left.isEmpty, !right.isEmpty else { return false }
        return left == right
    }

    private static func normalizedHost(_ host: String) -> String {
        var value = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if value.hasSuffix(".") {
            value.removeLast()
        }
        return value
    }

    private static func pinsMatch(_ presented: String, _ pinned: String) -> Bool {
        guard let left = Data(base64Encoded: presented),
              let right = Data(base64Encoded: pinned),
              left.count == 32,
              right.count == 32,
              left.count == right.count
        else { return false }
        var mismatch: UInt8 = 0
        for index in left.indices {
            mismatch |= left[index] ^ right[index]
        }
        return mismatch == 0
    }

    private static func leafCertificate(in trust: SecTrust) -> SecCertificate? {
        guard let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate] else { return nil }
        return chain.first
    }

    private static func subjectPublicKeyInfo(key: SecKey, point: Data) -> Data? {
        guard point.first == 0x04,
              let attributes = SecKeyCopyAttributes(key) as? [String: Any],
              let keyType = attributes[kSecAttrKeyType as String] as? String,
              keyType == (kSecAttrKeyTypeECSECPrimeRandom as String)
        else { return nil }
        let bits = (attributes[kSecAttrKeySizeInBits as String] as? NSNumber)?.intValue
        let header: [UInt8]
        switch (bits, point.count) {
        case (256, 65):
            header = ECSubjectPublicKey.p256Header
        case (384, 97):
            header = ECSubjectPublicKey.p384Header
        default:
            return nil
        }
        var spki = Data(header)
        spki.append(point)
        return spki
    }
}

private enum ECSubjectPublicKey {
    static let p256Header: [UInt8] = [
        0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01,
        0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07, 0x03, 0x42, 0x00,
    ]
    static let p384Header: [UInt8] = [
        0x30, 0x76, 0x30, 0x10, 0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01,
        0x06, 0x05, 0x2B, 0x81, 0x04, 0x00, 0x22, 0x03, 0x62, 0x00,
    ]
}
