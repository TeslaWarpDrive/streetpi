import Foundation

/// The house pin is the SPKI SHA-256 from the live audit. Settings can replace it.
public enum PiholePin {
    public static let houseSPKI = "lDT1PbNsR197fgVM+1rlXJMbTjMNg7forqemXVQX/7Y="
    public static let question = "The ad blocker's security certificate changed, trust the new one?"

    public static func sha256Base64(_ data: Data) -> String {
        SHA256Digest.hash(data).base64EncodedString()
    }

    public static func isSHA256Pin(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = Data(base64Encoded: trimmed) else { return false }
        return data.count == 32
    }

    /// A saved fixture fingerprint is not a pin. Callers then use the house default.
    public static func effective(_ stored: String?) -> String {
        guard let stored, isSHA256Pin(stored) else { return houseSPKI }
        return stored.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func matches(presented: String, expected: String) -> Bool {
        let left = presented.trimmingCharacters(in: .whitespacesAndNewlines)
        let right = expected.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isSHA256Pin(left), isSHA256Pin(right), left.count == right.count else { return false }
        var difference = 0
        for (first, second) in zip(left.utf8, right.utf8) {
            difference |= Int(first ^ second)
        }
        return difference == 0
    }
}

public enum PiholeBaseAddress {
    public static let houseText = "https://192.168.1.78/api"

    public static func endpoint(from text: String) -> PiholeEndpoint? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme == "https", let host = url.host, !host.isEmpty else {
            return nil
        }
        if let port = url.port, port != 443 {
            return nil
        }
        let path = url.path
        guard path.isEmpty || path == "/api" || path == "/api/" else { return nil }
        guard !host.contains(" ") else { return nil }
        return PiholeEndpoint(host: host, port: 443)
    }
}
