import Foundation

public struct NetdataReader<Transport: NetdataTransport>: Sendable {
    public var transport: Transport

    public init(transport: Transport) {
        self.transport = transport
    }

    public func load() async throws -> NetdataMeters {
        let info = try await infoBody()
        let hostName = try NetdataDecode.hostName(from: info)
        let plan = NetdataDecode.chartPlan(from: await chartsBody())
        async let cpu = tryPoint(plan.cpu, fallbacks: [])
        async let memory = tryPoint(plan.memory, fallbacks: [])
        async let disk = tryPoint(plan.disk, fallbacks: NetdataDecode.diskCandidates)
        async let uptime = tryPoint(plan.uptime, fallbacks: [])
        let temperature = try await tryPoint(plan.temperature, fallbacks: NetdataDecode.temperatureCandidates)
        let reading = NetdataDecode.reading(
            cpu: try await cpu,
            memory: try await memory,
            disk: try await disk,
            temperature: temperature,
            uptime: try await uptime
        )
        return NetdataMeters(hostName: hostName, reading: reading)
    }

    private func infoBody() async throws -> Data {
        let first = try await fetch("/api/v1/info")
        if NetdataDecode.isRedirect(first) { throw NetdataProblem.redirected }
        if usableJSON(first) { return first.body }
        let second = try await fetch("/api/v2/info")
        if NetdataDecode.isRedirect(second) { throw NetdataProblem.redirected }
        guard usableJSON(second) else { throw NetdataProblem.notUnderstood }
        return second.body
    }

    private func chartsBody() async -> Data? {
        guard let reply = try? await fetch("/api/v1/charts") else { return nil }
        if NetdataDecode.isRedirect(reply) { return nil }
        return usableJSON(reply) ? reply.body : nil
    }

    private func tryPoint(_ chart: String?, fallbacks: [String]) async throws -> NetdataPoint? {
        var names: [String] = []
        if let chart { names.append(chart) }
        for name in fallbacks where !names.contains(name) {
            names.append(name)
        }
        for name in names {
            if let point = try await point(chart: name) {
                return point
            }
        }
        return nil
    }

    private func point(chart: String) async throws -> NetdataPoint? {
        let primary = try await chartReply(chart: chart, version: 1)
        switch primary {
        case .point(let point):
            return point
        case .missing:
            return nil
        case .unreadable:
            let secondary = try await chartReply(chart: chart, version: 2)
            if case .point(let point) = secondary { return point }
            return nil
        }
    }

    private func chartReply(chart: String, version: Int) async throws -> ChartReply {
        let reply = try await fetch(NetdataAPI.dataPath(chart: chart, version: version))
        if NetdataDecode.isRedirect(reply) { throw NetdataProblem.redirected }
        guard (200..<300).contains(reply.status) else { return .missing }
        guard NetdataDecode.isJSONObject(reply.body) else { return .unreadable }
        guard let point = try? NetdataDecode.point(from: reply.body) else { return .missing }
        return .point(point)
    }

    private func fetch(_ path: String) async throws -> NetdataReply {
        do {
            return try await transport.get(path)
        } catch let problem as NetdataProblem {
            throw problem
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw NetdataProblem.offline
        }
    }

    private func usableJSON(_ reply: NetdataReply) -> Bool {
        (200..<300).contains(reply.status) && NetdataDecode.isJSONObject(reply.body)
    }
}

private enum ChartReply {
    case point(NetdataPoint)
    case missing
    case unreadable
}

extension MachineReading {
    public var hasSignal: Bool {
        cpuUsedFraction != nil
            || temperatureCelsius != nil
            || memoryUsedFraction != nil
            || diskUsedFraction != nil
            || uptimeSeconds != nil
    }
}
