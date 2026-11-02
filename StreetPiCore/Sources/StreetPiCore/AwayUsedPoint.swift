import Foundation

public struct AwayUsedPoint: Sendable, Equatable, Codable {
    public var time: Int
    public var used: Int

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case time = "t"
        case used
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(keyedBy: CodingKeys.self)
        time = try container.decode(Int.self, forKey: .time)
        used = try container.decode(Int.self, forKey: .used)
    }
}
