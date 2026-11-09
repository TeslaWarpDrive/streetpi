import AVFoundation
import StreetPiCore
import SwiftUI
import UIKit

enum SplashFilm {
    static let videoName = "launch-film"
    static let posterName = "launch-poster"
    static let crossfade: TimeInterval = 0.6
    static let stillHold: Duration = .milliseconds(800)

    static func videoURL() -> URL? {
        Bundle.main.url(forResource: videoName, withExtension: "mp4")
    }

    static func poster() -> UIImage? {
        guard let url = Bundle.main.url(forResource: posterName, withExtension: "png") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}

@MainActor
final class SplashPlayerModel {
    let player: AVPlayer

    init() {
        let player = AVPlayer()
        player.actionAtItemEnd = .pause
        player.allowsExternalPlayback = false
        player.audiovisualBackgroundPlaybackPolicy = .pauses
        self.player = player
    }

    func play(url: URL) async {
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        player.play()
        let started = Date()
        var sawPlayback = false
        while !Task.isCancelled {
            if player.timeControlStatus == .playing {
                sawPlayback = true
            }
            if item.status == .failed || reachedEnd(of: item, sawPlayback: sawPlayback, started: started) {
                return
            }
            do {
                try await Task.sleep(for: .milliseconds(80))
            } catch {
                return
            }
        }
    }

    private func reachedEnd(of item: AVPlayerItem, sawPlayback: Bool, started: Date) -> Bool {
        let duration = item.duration.isNumeric ? item.duration.seconds : nil
        let gap = CMTimeSubtract(item.duration, item.currentTime())
        let remaining = gap.isNumeric ? gap.seconds : nil
        return LaunchFilmPlayback.reachedEnd(
            duration: duration,
            elapsed: Date().timeIntervalSince(started),
            remaining: remaining,
            sawPlayback: sawPlayback,
            transport: .init(player.timeControlStatus)
        )
    }
}

private extension LaunchFilmPlayback.Transport {
    init(_ status: AVPlayer.TimeControlStatus) {
        switch status {
        case .playing:
            self = .playing
        case .paused:
            self = .paused
        case .waitingToPlayAtSpecifiedRate:
            self = .waiting
        @unknown default:
            self = .waiting
        }
    }
}

struct SplashPlayerHost: View {
    var model: SplashPlayerModel

    var body: some View {
        SplashPlayerSurface(model: model)
            .accessibilityHidden(true)
    }
}

private struct SplashPlayerSurface: UIViewRepresentable {
    var model: SplashPlayerModel

    func makeUIView(context: Context) -> SplashPlayerCanvas {
        let canvas = SplashPlayerCanvas()
        canvas.attach(model.player)
        return canvas
    }

    func updateUIView(_ canvas: SplashPlayerCanvas, context: Context) {
        canvas.attach(model.player)
    }
}

private final class SplashPlayerCanvas: UIView {
    let playerLayer = AVPlayerLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = true
        backgroundColor = StreetColor.uiColor(StreetColor.auroraGround)
        playerLayer.backgroundColor = StreetColor.uiColor(StreetColor.auroraGround).cgColor
        playerLayer.videoGravity = .resizeAspectFill
        playerLayer.isOpaque = true
        layer.addSublayer(playerLayer)
        accessibilityElementsHidden = true
    }

    func attach(_ player: AVPlayer) {
        playerLayer.videoGravity = .resizeAspectFill
        if playerLayer.player !== player {
            playerLayer.player = player
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Splash player is built in code")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}
