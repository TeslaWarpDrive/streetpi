import StreetPiCore
import SwiftUI

/// Plain-English explainers for the ad blocker numbers.
enum AdBlockerCopy {
    static func percent(_ share: LookupShare) -> NumberExplainer {
        NumberExplainer(
            title: "About this percent",
            text: "This is the share of lookups the Pi stopped in the last 24 hours. "
                + "Before a phone, TV, or laptop loads a page or an app, it asks the Pi for the address. "
                + "When the name is on a block list, the Pi does not answer, so that ad or tracker never loads. "
                + share.fractionLine
        )
    }

    static func stopped(_ share: LookupShare) -> NumberExplainer {
        NumberExplainer(
            title: "About stopped",
            text: "In the last 24 hours the Pi turned away \(share.stopped.formatted()) lookups "
                + "because the name was on a block list. Most of them are ads and trackers inside apps and pages."
        )
    }

    static func lookups(_ share: LookupShare) -> NumberExplainer {
        NumberExplainer(
            title: "About lookups",
            text: "Every time a device needs an address, it asks the Pi. "
                + "In the last 24 hours the house asked \(share.lookups.formatted()) times, stopped or not."
        )
    }

    static func lastHour(_ share: LookupShare) -> NumberExplainer {
        let count = share.lastHourStopped.map { $0.formatted() } ?? "No count yet"
        return NumberExplainer(
            title: "About the last hour",
            text: "Lookups the Pi stopped in the most recent hour: \(count). "
                + "A quiet hour is normal at night, when most devices are asleep."
        )
    }

    static func meaning(_ share: LookupShare) -> String {
        "Every time a phone, TV, or laptop goes online, it first asks the Pi where the site lives. "
            + "In the last 24 hours your devices asked \(share.lookups.formatted()) times, and the Pi stopped "
            + "\(share.stopped.formatted()) of those because they were ads or trackers. "
            + share.fractionLine
    }
}

