# StreetPi agent rules

## MANDATORY DESIGN SUITE

Every thread that changes the app inherits this rule. Do not skip a tool, swap one out, or quietly replace it. If you believe a tool below is a bad idea for this app, stop and report why before writing code.

1. **Paul Hudson, SwiftUI Pro.** https://github.com/twostraws/SwiftUI-Agent-Skill — read `swiftui-pro/SKILL.md` and the reference that matches the change (accessibility, views, navigation, data, design) before writing or reviewing SwiftUI.
2. **Thomas Ricouard, Liquid Glass and UI patterns.** https://github.com/Dimillian/Skills — `swiftui-liquid-glass` and `swiftui-ui-patterns`. Liquid Glass on iOS 26 and later. On older iOS, use a tasteful material fallback. Glass is for chrome and the Briefing card, not for body text.
3. **Point-Free swift-snapshot-testing.** https://github.com/pointfreeco/swift-snapshot-testing — visual review loop. Every screen in dark, default and largest Dynamic Type, small iPhone, large iPhone, and iPad. Review the images and fix what looks off before calling the work done.
4. **SF Symbols 7 and native SwiftUI animation and symbol effects.** Pow (https://github.com/EmergeTools/Pow) stays optional and is unused. Do not vendor it.
5. **Design taste.** The direction is Aurora, and the app is dark only. Ban generic defaults: no stock “AI app” gradients. The Aurora glow family is the only gradient: the Home aura, the ring arcs, and the headline accent word (like “good”). No gradients elsewhere. No default List inside a NavigationStack where a designed screen belongs. Run the pre-ship checklist below.

### SwiftUI Pro rules that always apply

- Dynamic Type text styles. Do not lock font sizes. Largest accessibility size must wrap or scroll, not clip.
- `foregroundStyle`, not `foregroundColor`. `NavigationSplitView` / `NavigationStack`, not `NavigationView`.
- Buttons are `Button`. Icon-only controls still carry a text label and `.labelStyle(.iconOnly)`.
- Decorative images are `accessibilityHidden`. Status is never color alone: pair a color with a word or a different symbol.
- When Reduce Motion is on, skip movement. Opacity is enough.
- No `AnyView`, no `onTapGesture` for ordinary taps, no force-unwrap.

### Liquid Glass rules that always apply

- Prefer `glassEffect`, `GlassEffectContainer`, and `.buttonStyle(.glass)` over custom blurs.
- Put `.glassEffect` after padding and other layout modifiers.
- Wrap multiple glass siblings in `GlassEffectContainer`.
- `.interactive()` only on controls the person can touch.
- Gate with `#available(iOS 26, *)` and keep a material or solid fallback.

### Visual review matrix

For every screen: dark, Dynamic Type `.large`, Dynamic Type `.accessibility5`, small iPhone, large iPhone, iPad. The tests live in `StreetPiTests/DesignSnapshotTests.swift`. Missing references record on the next macOS run. Look at the PNGs.

### Pre-ship checklist

- The app is dark only. There is no light palette and no appearance switch.
- The look is Aurora. Home follows `home-v2.png`: compact status, a lavender ad blocker card beside Pi temperature and meters, service tiles, monitor squares, and quiet household facts. The ad blocker follows `ad-blocker-v2.png`, shared between the Home sheet and the first Ad blocker tab page. Briefing and ring gauges remain the design language for detailed Pi pages. The Porch card and Lampblack direction are retired. Do not bring back a direction picker.
- Keep Home compact and good-looking. A vertical stack is fine when the content fits. When a screen has a lot of data, many stat cards, graphs, or other dense information, do not make it a long one-card column. Choose the arrangement that looks best for that amount of content. There is no fixed column count. Large text must wrap or scroll, and nothing truncates or overlaps. The Home screen follows this when it is built.
- Tabs are House, Ad blocker, Pi, and Settings. The iPad uses a sidebar.
- The launch film is one file, `StreetPi/Resources/launch-film.mp4`. Replace that file to change the film. Do not add a second video. It is silent and full-screen on the Aurora ground. Tap to skip. It fades into the Home aura. Reduce Motion shows `launch-poster.png`, then fades, and does not play the video. `LaunchOverlay` is that seam.
- The product name is Raspberry Pi Stats. Under the icon it is Pi Stats, because the full name truncates. Code modules stay `StreetPi` and `StreetPiCore`.
- Copy is original plain English. Alerts never name a person. No text, icons, or screenshots from Open Pi or Pi-hole Remote.
- Reduce Motion, VoiceOver labels, and Dynamic Type were considered.
- No analytics, ads, crash reporting, or tracking SDK.
- No secret in the repo, in logs, or in a fixture that pretends to be real.

## Product constraints

- One app for everyone in the house. No per-person screens, modes, or areas. Face ID protects a destructive action, not a person.
- iOS 18 minimum. Swift 6. iPhone and iPad. Tabs are House, Ad blocker, Pi, and Settings. Sidebar on iPad.
- `StreetPiCore` is pure Swift and must pass `swift test` on Linux. The app is a thin SwiftUI layer.
- Fixtures and mocks only until a later phase. No network call to a real host. No Tailscale. No changes to the Pi, router, DNS, or port forwards.
- Secrets live in the iOS Keychain. ATS allows local networking only. Never set `NSAllowsArbitraryLoads`.
- Free sideload. CI produces an unsigned `.ipa` on a standard macOS runner. No paid runner size. No Apple Developer Program. No paid SDK.
- No widgets, Live Activities, Watch app, or TV app in v1.
- No new dependency without asking. No Chinese-owned SDK or vendor. No unlicensed or GPL-3.0 code copied into the app.
