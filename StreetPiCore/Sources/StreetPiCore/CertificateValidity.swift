import Foundation

/// Reads the not-after date from a certificate. iOS does not expose the macOS
/// certificate-value API, so this walks the DER the certificate already carries.
public enum CertificateValidity {
    public static func notAfter(der: Data) -> Date? {
        var certificate = DERReader(der)
        guard let certificateBody = certificate.sequenceContents() else { return nil }
        var certificateFields = DERReader(certificateBody)
        guard let tbs = certificateFields.sequenceContents() else { return nil }
        var fields = DERReader(tbs)
        if fields.peek == 0xA0 {
            guard fields.skip() else { return nil }
        }
        guard fields.skip(), fields.skip(), fields.skip() else { return nil }
        guard let validity = fields.sequenceContents() else { return nil }
        var times = DERReader(validity)
        guard times.skip() else { return nil }
        return times.time()
    }

    /// SubjectPublicKeyInfo bytes, tag included. This is the SPKI a pin hashes.
    public static func subjectPublicKeyInfo(der: Data) -> Data? {
        var certificate = DERReader(der)
        guard let certificateBody = certificate.sequenceContents() else { return nil }
        var certificateFields = DERReader(certificateBody)
        guard let tbs = certificateFields.sequenceContents() else { return nil }
        var fields = DERReader(tbs)
        if fields.peek == 0xA0 {
            guard fields.skip() else { return nil }
        }
        guard fields.skip(), fields.skip(), fields.skip(), fields.skip(), fields.skip() else { return nil }
        return fields.element()
    }
}

private struct DERReader {
    private let bytes: [UInt8]
    private var index = 0

    init(_ data: Data) {
        bytes = [UInt8](data)
    }

    var peek: UInt8? {
        index < bytes.count ? bytes[index] : nil
    }

    mutating func sequenceContents() -> Data? {
        guard peek == 0x30, skipTag(), let count = length(), let slice = take(count) else {
            return nil
        }
        return Data(slice)
    }

    mutating func skip() -> Bool {
        element() != nil
    }

    mutating func element() -> Data? {
        let start = index
        guard skipTag(), let count = length(), take(count) != nil else { return nil }
        return Data(bytes[start..<index])
    }

    mutating func time() -> Date? {
        guard let tag = peek, tag == 0x17 || tag == 0x18 else { return nil }
        guard skipTag(), let count = length(), let slice = take(count) else { return nil }
        let text = String(bytes: slice, encoding: .utf8) ?? ""
        return Self.date(text, generalized: tag == 0x18)
    }

    private mutating func skipTag() -> Bool {
        guard index < bytes.count else { return false }
        index += 1
        return true
    }

    private mutating func length() -> Int? {
        guard let first = next() else { return nil }
        if first < 0x80 { return Int(first) }
        let count = Int(first & 0x7F)
        guard (1...3).contains(count) else { return nil }
        var value = 0
        for _ in 0..<count {
            guard let byte = next() else { return nil }
            value = (value << 8) | Int(byte)
        }
        guard value <= bytes.count - index else { return nil }
        return value
    }

    private mutating func next() -> UInt8? {
        guard index < bytes.count else { return nil }
        let byte = bytes[index]
        index += 1
        return byte
    }

    private mutating func take(_ count: Int) -> [UInt8]? {
        guard count >= 0, index + count <= bytes.count else { return nil }
        let slice = Array(bytes[index..<(index + count)])
        index += count
        return slice
    }

    private static func date(_ text: String, generalized: Bool) -> Date? {
        let expected = generalized ? 15 : 13
        guard text.count == expected, text.last == "Z" else { return nil }
        let digits = text.dropLast()
        guard digits.allSatisfy({ $0 >= "0" && $0 <= "9" }) else { return nil }
        let chars = Array(digits)
        func piece(_ start: Int, _ count: Int) -> Int? {
            Int(String(chars[start..<(start + count)]))
        }
        let year: Int
        let origin: Int
        if generalized {
            guard let value = piece(0, 4) else { return nil }
            year = value
            origin = 4
        } else {
            guard let yy = piece(0, 2) else { return nil }
            year = yy >= 50 ? 1_900 + yy : 2_000 + yy
            origin = 2
        }
        guard let month = piece(origin, 2),
              let day = piece(origin + 2, 2),
              let hour = piece(origin + 4, 2),
              let minute = piece(origin + 6, 2),
              let second = piece(origin + 8, 2)
        else { return nil }
        var calendar = Calendar(identifier: .gregorian)
        if let zone = TimeZone(secondsFromGMT: 0) {
            calendar.timeZone = zone
        }
        return calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour,
                minute: minute,
                second: second
            )
        )
    }
}
