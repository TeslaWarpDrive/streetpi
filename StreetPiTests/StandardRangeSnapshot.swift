import CoreGraphics
import SnapshotTesting
import UIKit
import XCTest

extension Snapshotting where Format == UIImage {
    /// Compare the same 8-bit sRGB representation on disk and in memory.
    func standardRange() -> Self {
        var strategy = self
        let render = snapshot
        strategy.snapshot = { value in
            render(value).map { image in
                guard let source = image.cgImage,
                      let space = CGColorSpace(name: CGColorSpace.sRGB),
                      let context = CGContext(
                        data: nil,
                        width: source.width,
                        height: source.height,
                        bitsPerComponent: 8,
                        bytesPerRow: source.width * 4,
                        space: space,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                      ) else {
                    XCTFail("Could not create a standard-range snapshot context")
                    return image
                }
                context.draw(source, in: CGRect(x: 0, y: 0, width: source.width, height: source.height))
                guard let normalized = context.makeImage() else {
                    XCTFail("Could not create a standard-range snapshot image")
                    return image
                }
                return UIImage(cgImage: normalized, scale: image.scale, orientation: image.imageOrientation)
            }
        }
        return strategy
    }
}
