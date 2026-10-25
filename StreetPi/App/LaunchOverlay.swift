import SwiftUI
import UIKit

/// Launch film. Tap anywhere to skip. Reduce Motion holds the poster, then fades. It does not play video.
struct LaunchOverlay: View {
    var frame: UIImage?
    var onFinished: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.streetPiStill) private var still
    @State private var model: SplashPlayerModel?
    @State private var poster: UIImage?
    @State private var playFilm = true
    @State private var didFinish = false

    var body: some View {
        ZStack {
            StreetColor.rgb(StreetColor.auroraGround)
            if let image = shownImage {
                SplashPoster(image: image)
            } else if showsPlayer, let model {
                SplashPlayerHost(model: model)
            }
            Button(action: finish) {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Raspberry Pi Stats")
            .accessibilityHint("Skips the introduction")
        }
        .ignoresSafeArea()
        .statusBarHidden(true)
        .persistentSystemOverlays(.hidden)
        .task { await run() }
        .onDisappear(perform: halt)
    }

    private var showsPlayer: Bool {
        frame == nil && playFilm && !reduceMotion && !still
    }

    private var shownImage: UIImage? {
        if let frame { return frame }
        return showsPlayer ? nil : poster
    }

    private func run() async {
        if frame != nil { return }
        if reduceMotion || still {
            await holdStill()
            return
        }
        await play()
    }

    private func holdStill() async {
        poster = SplashFilm.poster()
        do {
            try await Task.sleep(for: SplashFilm.stillHold)
        } catch {
            return
        }
        finish()
    }

    private func play() async {
        guard let url = SplashFilm.videoURL() else {
            finish()
            return
        }
        let playback = SplashPlayerModel()
        model = playback
        await Task.yield()
        await playback.play(url: url)
        guard !Task.isCancelled, !didFinish else { return }
        poster = SplashFilm.poster()
        playFilm = false
        finish()
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        halt()
        onFinished()
    }

    private func halt() {
        model?.player.pause()
    }
}

extension View {
    /// The launch-film seam. A later film replaces `LaunchOverlay` without another hook.
    func launchOverlay(isPresented: Binding<Bool>) -> some View {
        overlay {
            if isPresented.wrappedValue {
                LaunchOverlay {
                    isPresented.wrappedValue = false
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: SplashFilm.crossfade), value: isPresented.wrappedValue)
    }
}
