# StreetPi

StreetPi is one iPhone and iPad app for the Street house. The repository is [https://github.com/TeslaWarpDrive/streetpi](https://github.com/TeslaWarpDrive/streetpi). The earlier owner name CryptoBrad89 is not used. This tree does not link to it.

Agents follow `AGENTS.md`. This file records decisions that are already closed.

## Design

Bradley approved the Briefing and ring-gauge layout on 2026-10-24, then rejected the warm near-black and orange glow the same day and picked Aurora. Layout, features, and motion stay. Later phases are not approved yet.

Aurora replaces the Porch card and the Lampblack bar meters. Home uses a Briefing and ring gauges. Each ring keeps its label and a plain word. The word for warmth belongs with Temperature.

Dark is designed first. Light mode is Daylight, and it is a real design.

Tabs are House, Ad blocker, Pi, and Settings. The iPad uses a sidebar.

The video splash stays. Its end tint is the Aurora ground. A moving crossfade from the film into the Home aura is not built yet.

The only gradient is the Aurora glow family: the Home aura, the ring arcs, and the headline accent word (like “good”). No gradients elsewhere. There is no stock purple AI gradient.

The app icon refresh waits for the release phase. This decision does not change the icon.

Version 1.0.0 still draws the porch card and the bar meters. Those screens change in later work. The rule from here is Aurora.

Mockups show mood. They are not final pixels. Do not copy a "Cool" label under Memory, a duplicate gear on the Pi screen, a static border where a beam should move, alert copy that names a person, or a missing slice on the icon pie. Alerts never name a person.

## What stays

- Never change the Pi, the router, DNS, or port forwards.
- No Tailscale.
- Secrets live only in the iOS Keychain. Never commit a secret or print one.
- No analytics, ads, crash reporting, or tracking.
- No new dependency without asking.
- No Chinese-owned SDK or vendor.
- No unlicensed or GPL-3.0 code copied into the app.
- Plain-English copy.
- Accessibility and Reduce Motion. Status is never color alone.
- iOS 18 minimum. Swift 6. iPhone and iPad.
- `StreetPiCore` is pure Swift and must pass `swift test` on Linux. The app is a thin SwiftUI layer.
- Fixtures and mocks only. No network call to a real host.
- ATS allows local networking only. Never set `NSAllowsArbitraryLoads`.
- Free sideload. CI produces an unsigned `.ipa` on the standard macOS runner.
- No widgets, Live Activities, Watch app, or TV app in v1.
- The design suite stays: SwiftUI Pro, Liquid Glass with a material fallback on older iOS, swift-snapshot-testing, and SF Symbols 7. Pow is unused.
- One app for the whole house. Face ID protects a destructive action, not a person.
