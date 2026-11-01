import StreetPiCore

/// One read of the live query log and the upkeep text log.
struct LogPull {
    var queries: LiveLogFeed
    var text: TextLogFeed
    var liveNote: String?
    var textNote: String?

    static func both(client: PiholeClient, textFeed: TextLogFeed, queryFeed: LiveLogFeed) async -> LogPull {
        async let live = live(client: client, feed: queryFeed)
        async let text = text(client: client, feed: textFeed)
        let liveResult = await live
        let textResult = await text
        return LogPull(
            queries: liveResult.feed,
            text: textResult.feed,
            liveNote: liveResult.note,
            textNote: textResult.note
        )
    }

    static func live(client: PiholeClient, feed: LiveLogFeed) async -> (feed: LiveLogFeed, note: String?) {
        do {
            let rows = try await client.liveQueries()
            return (feed.applying(rows), nil)
        } catch let problem as PiholeProblem {
            return (feed, LiveReadCopy.pihole(problem, fallback: LiveReadCopy.liveLog))
        } catch {
            return (feed, LiveReadCopy.offline)
        }
    }

    private static func text(client: PiholeClient, feed: TextLogFeed) async -> (feed: TextLogFeed, note: String?) {
        do {
            let page = try await client.textLog(after: feed.nextID)
            return (feed.applying(page), nil)
        } catch let problem as PiholeProblem {
            return (feed, LiveReadCopy.pihole(problem, fallback: LiveReadCopy.textLog))
        } catch {
            return (feed, LiveReadCopy.offline)
        }
    }
}
