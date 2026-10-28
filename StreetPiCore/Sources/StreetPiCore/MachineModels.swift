import Foundation

public struct MetricPoint: Sendable, Equatable, Identifiable, Codable {
    public var hour: Int
    public var value: Double

    public var id: Int { hour }

    public init(hour: Int, value: Double) {
        self.hour = hour
        self.value = value
    }
}

public struct MetricSeries: Sendable, Equatable, Identifiable, Codable {
    public var id: String
    public var title: String
    public var caption: String
    public var points: [MetricPoint]

    public init(id: String, title: String, caption: String, points: [MetricPoint]) {
        self.id = id
        self.title = title
        self.caption = caption
        self.points = points
    }
}

public struct HouseAlert: Sendable, Equatable, Identifiable, Codable {
    public var id: String
    public var sentence: String
    public var tone: PlainEnglishStatus.Tone
    /// When the alarm was raised. Nil when the source gave no time, so no time is shown.
    public var raisedAt: Date?

    public init(id: String, sentence: String, tone: PlainEnglishStatus.Tone, raisedAt: Date? = nil) {
        self.id = id
        self.sentence = sentence
        self.tone = tone
        self.raisedAt = raisedAt
    }
}

public enum MachinePage: String, CaseIterable, Sendable, Equatable, Identifiable {
    case dashboard
    case chart
    case services
    case containers

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .dashboard: "The Pi"
        case .chart: "Charts"
        case .services: "Services"
        case .containers: "Containers"
        }
    }

    public var blurb: String {
        switch self {
        case .dashboard: "How the Pi is doing right now."
        case .chart: "The last day, from the charts."
        case .services: "Up or down, from the status page."
        case .containers: "The boxed jobs on the charts."
        }
    }

    public var symbolName: String {
        switch self {
        case .dashboard: "cpu"
        case .chart: "chart.xyaxis.line"
        case .services: "gearshape"
        case .containers: "shippingbox"
        }
    }
}
