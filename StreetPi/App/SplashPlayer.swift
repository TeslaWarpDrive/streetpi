import AVFoundation
import SwiftUI

/// Ambient mixes with the person's music and goes quiet when the phone is on silent.
@MainActor
enum SplashAudio {
    private static var engaged = false

    static func startAmbient() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, mode: .default)
            try session.setActive(true)
            engaged = true
        } catch {
            engaged = false
        }
    }

    static func stop() {
        guard engaged else { return }
        engaged = false
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
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
        guard item.duration.isNumeric else { return false }
        if Date().timeIntervalSince(started) > item.duration.seconds + 3 { return true }
        guard sawPlayback else { return false }
        let remaining = CMTimeSubtract(item.duration, item.currentTime())
        guard remaining.isNumeric else { return false }
        if remaining.seconds <= 0.05 { return true }
        return remaining.seconds <= 0.2 && player.timeControlStatus != .playing
    }
}

struct SplashPlayerHost: View {
    var model: SplashPlayerModel

    var body: some View {
        GeometryReader { proxy in
            let fit = SplashLayout.fit(viewSize: proxy.size)
            SplashPlayerSurface(
                model: model,
                gravity: fit == .letterbox ? .resizeAspect : .resizeAspectFill
            )
        }
        .accessibilityHidden(true)
    }
}

private struct SplashPlayerSurface: UIViewRepresentable {
    var model: SplashPlayerModel
    var gravity: AVLayerVideoGravity

    func makeUIView(context: Context) -> SplashPlayerCanvas {
        let canvas = SplashPlayerCanvas()
        canvas.attach(model.player, gravity: gravity)
        return canvas
    }

    func updateUIView(_ canvas: SplashPlayerCanvas, context: Context) {
        canvas.attach(model.player, gravity: gravity)
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

    func attach(_ player: AVPlayer, gravity: AVLayerVideoGravity) {
        playerLayer.videoGravity = gravity
        if playerLayer.player !== player {
            playerLayer.player = player
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("StreetPi splash player is built in code")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}
