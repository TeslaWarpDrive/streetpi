import SwiftUI

enum SplashFit: Equatable {
    case fill
    case letterbox
}

/// Phones always fill. An iPad letterboxes only when filling would crop the picture hard.
enum SplashLayout {
    static let authoredMedia = CGSize(width: 854, height: 480)
    static let padMinimum: CGFloat = 700
    /// A fill that hides more than about a third of one axis is a bad crop.
    static let badCropRatio: CGFloat = 1.5
    static let stillHold: Duration = .milliseconds(800)
    static let resourceName = "StreetPiSplash"
    static let endImageName = "StreetPiSplashEnd"

    /// Aurora ground, so the film ends on the same color as the house.
    /// A moving crossfade from the film into the Home aura is not built yet.
    static var backdrop: Color {
        StreetColor.rgb(StreetColor.auroraGround)
    }

    static func fit(viewSize: CGSize, mediaSize: CGSize = authoredMedia) -> SplashFit {
        guard viewSize.width > 1, viewSize.height > 1 else { return .fill }
        guard min(viewSize.width, viewSize.height) >= padMinimum else { return .fill }
        guard mediaSize.width > 1, mediaSize.height > 1 else { return .fill }
        let viewAspect = viewSize.width / viewSize.height
        let mediaAspect = mediaSize.width / mediaSize.height
        let mismatch = max(viewAspect, mediaAspect) / min(viewAspect, mediaAspect)
        return mismatch > badCropRatio ? .letterbox : .fill
    }
}
