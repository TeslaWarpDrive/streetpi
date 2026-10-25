import SwiftUI
import UIKit

/// One frame of the launch film, aspect-filled over the Aurora ground.
struct SplashPoster: View {
    var image: UIImage

    var body: some View {
        GeometryReader { proxy in
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
        .accessibilityHidden(true)
    }
}
