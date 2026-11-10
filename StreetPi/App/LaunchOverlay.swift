import StreetPiCore
import SwiftUI
import UIKit

/// Launch film. Tap anywhere to skip. Reduce Motion holds the poster, then fades. It does not play video.
struct LaunchOverlay: View {
    var frame: UIImage?
    var onFinished: () -> Void = {}
    var handoffPreview = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.streetPiStill) private var still
    @State private var model: SplashPlayerModel?
    @State private var poster: UIImage?
    @State private var playFilm = true
    @State private var didFinish = false
    @State private var handingOff = false

    var body: some View {
        ZStack {
            StreetColor.rgb(StreetColor.auroraGround)
            if let image = shownImage {
                SplashPoster(image: image)
            } else if showsPlayer, let model {
                SplashPlayerHost(model: model)
            }
            HomeAura(tone: .calm)
                .opacity(handingOff || handoffPreview ? 1 : 0)
                .scaleEffect(reduceMotion || handingOff || handoffPreview ? 1 : 1.15)
            Button(action: skip) {
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
        .onChange(of: scenePhase) { _, phase in
            respond(to: .scene(.init(phase)))
        }
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
            respond(to: .sleepCancelled)
            return
        }
        respond(to: .stillHeld)
    }

    private func play() async {
        guard let url = SplashFilm.videoURL() else {
            respond(to: .missingFilm)
            return
        }
        let playback = SplashPlayerModel()
        model = playback
        await Task.yield()
        guard !didFinish else { return }
        await playback.play(url: url)
        guard !Task.isCancelled, !didFinish else { return }
        poster = SplashFilm.poster()
        playFilm = false
        respond(to: .playbackEnded)
    }

    private func skip() {
        respond(to: .tap)
    }

    private func respond(to cue: LaunchFilmCue) {
        guard LaunchFilmHandoff.step(cue, alreadyFinished: didFinish) == .finish else { return }
        finish()
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        halt()
        withAnimation(.easeInOut(duration: SplashFilm.crossfade)) {
            handingOff = true
        } completion: {
            onFinished()
        }
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

private extension LaunchFilmCue.Scene {
    init(_ phase: ScenePhase) {
        switch phase {
        case .active:
            self = .active
        case .inactive:
            self = .inactive
        case .background:
            self = .background
        @unknown default:
            self = .active
        }
    }
}
