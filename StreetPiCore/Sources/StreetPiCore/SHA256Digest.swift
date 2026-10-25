import Foundation

/// SHA-256 for the certificate pin. No extra package. StreetPiCore stays free of sockets.
enum SHA256Digest {
    static func hash(_ data: Data) -> Data {
        var words = initial
        var message = [UInt8](data)
        let bitLength = UInt64(message.count) * 8
        message.append(0x80)
        while message.count % 64 != 56 {
            message.append(0)
        }
        for shift in stride(from: 56, through: 0, by: -8) {
            message.append(UInt8((bitLength >> shift) & 0xFF))
        }
        var index = 0
        while index < message.count {
            var schedule = [UInt32](repeating: 0, count: 64)
            for word in 0..<16 {
                let start = index + word * 4
                let first = UInt32(message[start]) << 24
                let second = UInt32(message[start + 1]) << 16
                let third = UInt32(message[start + 2]) << 8
                schedule[word] = first | second | third | UInt32(message[start + 3])
            }
            for word in 16..<64 {
                let older = schedule[word - 15]
                let newer = schedule[word - 2]
                let small = rotate(older, 7) ^ rotate(older, 18) ^ (older >> 3)
                let large = rotate(newer, 17) ^ rotate(newer, 19) ^ (newer >> 10)
                schedule[word] = schedule[word - 16] &+ small &+ schedule[word - 7] &+ large
            }
            var working = words
            for round in 0..<64 {
                let sum1 = rotate(working[4], 6) ^ rotate(working[4], 11) ^ rotate(working[4], 25)
                let choice = (working[4] & working[5]) ^ (~working[4] & working[6])
                let first = working[7] &+ sum1 &+ choice &+ constants[round] &+ schedule[round]
                let sum0 = rotate(working[0], 2) ^ rotate(working[0], 13) ^ rotate(working[0], 22)
                let majority = (working[0] & working[1]) ^ (working[0] & working[2]) ^ (working[1] & working[2])
                working[7] = working[6]
                working[6] = working[5]
                working[5] = working[4]
                working[4] = working[3] &+ first
                working[3] = working[2]
                working[2] = working[1]
                working[1] = working[0]
                working[0] = first &+ sum0 &+ majority
            }
            for index in 0..<8 {
                words[index] = words[index] &+ working[index]
            }
            index += 64
        }
        var digest = Data()
        digest.reserveCapacity(32)
        for word in words {
            digest.append(UInt8((word >> 24) & 0xFF))
            digest.append(UInt8((word >> 16) & 0xFF))
            digest.append(UInt8((word >> 8) & 0xFF))
            digest.append(UInt8(word & 0xFF))
        }
        return digest
    }

    private static func rotate(_ value: UInt32, _ places: UInt32) -> UInt32 {
        (value >> places) | (value << (32 - places))
    }

    private static let initial: [UInt32] = [
        0x6A09E667, 0xBB67AE85, 0x3C6EF372, 0xA54FF53A,
        0x510E527F, 0x9B05688C, 0x1F83D9AB, 0x5BE0CD19,
    ]

    private static let constants: [UInt32] = [
        0x428A2F98, 0x71374491, 0xB5C0FBCF, 0xE9B5DBA5, 0x3956C25B, 0x59F111F1, 0x923F82A4, 0xAB1C5ED5,
        0xD807AA98, 0x12835B01, 0x243185BE, 0x550C7DC3, 0x72BE5D74, 0x80DEB1FE, 0x9BDC06A7, 0xC19BF174,
        0xE49B69C1, 0xEFBE4786, 0x0FC19DC6, 0x240CA1CC, 0x2DE92C6F, 0x4A7484AA, 0x5CB0A9DC, 0x76F988DA,
        0x983E5152, 0xA831C66D, 0xB00327C8, 0xBF597FC7, 0xC6E00BF3, 0xD5A79147, 0x06CA6351, 0x14292967,
        0x27B70A85, 0x2E1B2138, 0x4D2C6DFC, 0x53380D13, 0x650A7354, 0x766A0ABB, 0x81C2C92E, 0x92722C85,
        0xA2BFE8A1, 0xA81A664B, 0xC24B8B70, 0xC76C51A3, 0xD192E819, 0xD6990624, 0xF40E3585, 0x106AA070,
        0x19A4C116, 0x1E376C08, 0x2748774C, 0x34B0BCB5, 0x391C0CB3, 0x4ED8AA4A, 0x5B9CCA4F, 0x682E6FF3,
        0x748F82EE, 0x78A5636F, 0x84C87814, 0x8CC70208, 0x90BEFFFA, 0xA4506CEB, 0xBEF9A3F7, 0xC67178F2,
    ]
}
