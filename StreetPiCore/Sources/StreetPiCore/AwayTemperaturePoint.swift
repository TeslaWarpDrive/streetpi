import Foundation

public struct AwayTemperaturePoint: Sendable, Equatable, Codable {
    public var time: Int
    public var celsius: Double

    private enum CodingKeys: String, CodingKey, CaseIterable {
        case time = "t"
        case celsius = "c"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.strictContainer(keyedBy: CodingKeys.self)
        time = try container.decode(Int.self, forKey: .time)
        celsius = try container.decode(Double.self, forKey: .celsius)
    }
}
