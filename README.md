# Raspberry Pi Stats

Raspberry Pi Stats is a native iPhone and iPad app for the Street house. Under the icon the name is Pi Stats, because the full name truncates. One app, one experience. It says what the house is doing in plain English. The GitHub repository stays `streetpi`. The code modules stay `StreetPi` and `StreetPiCore`.

The screen is drawn from fake fixtures. It does not talk to the Pi, the router, or any other host. Version 1.0.0 is the first sideload. See `RELEASE-NOTES.md`.

Ad blocker & DNS opens the filter. Today shows blocking and a 24-hour chart of lookups. The only writes are a timed pause, blocking one domain, and allowing one domain. Each one asks in plain English first. Clients, groups, lists, local names, and upkeep are read-only. The text log file can be off; lookups are still kept. The app password and the Pi certificate pin stay in the Keychain. Nothing in this build opens a socket.

Pi health is look-only. It shows the processor, temperature, memory, disk, and uptime, plus a day chart. Services and containers are readings. Alerts stay in the app and never name a person. Nothing here opens a connection, and the phone does not keep an SSH key or a host pin.

## Look

Aurora, dark only. There is no light palette and no appearance switch. Home is a Briefing and ring gauges for Processor, Temperature, Memory, and Disk. The Porch card and the Lampblack bar meters are retired. The only gradient is the Aurora glow family: the Home aura, the ring arcs, and the headline accent word. The launch film is `StreetPi/Resources/launch-film.mp4`, silent and full-screen on the Aurora ground. Tap to skip. It fades into the Home aura. Reduce Motion shows the poster, then fades, and does not play the video. Replace that one file to change the film. Do not add a second video. `LaunchOverlay` is the seam.

Keep Home compact and good-looking. A vertical stack is fine when the content fits. When a screen has a lot of data, many stat cards, graphs, or other dense information, do not make it a long one-card column. Choose the arrangement that looks best for that amount of content. There is no fixed column count. Large text must wrap or scroll, and nothing truncates or overlaps. The Home screen follows this.

Tabs are House, Ad blocker, Pi, and Settings. The iPad uses a sidebar.

Closed decisions are in `docs/project-context.md`. The rules are in `AGENTS.md`. Version 1.0.0 still draws the earlier porch screens, in Aurora colors. This section is the rule from 2026-10-24.

## Layout

- `StreetPiCore` — domain model, plain-English status, fixture clients. Pure Swift. `make test-core` runs on Linux.
- `StreetPi` — SwiftUI app. iOS 18 minimum, iPhone and iPad.
- `StreetPi.xcodeproj` — open this, or `StreetPi.xcworkspace`.

Bundle id defaults to `com.streetfam.streetpi`. Override `STREETPI_BUNDLE_IDENTIFIER` in `Config/Shared.xcconfig`. `STREETPI_APP_GROUP_IDENTIFIER` is reserved and is not an entitlement yet.

Secrets go in the iOS Keychain (`KeychainSecretStore`). Tests use `MemorySecretStore` and the strings `fixture-not-a-real-secret` and `fixture-not-a-real-password`. Those strings are never printed.

## CI

GitHub Actions runs the core tests on Ubuntu and, on a standard `macos-26` runner, the snapshot matrix plus an unsigned `StreetPi-unsigned.ipa`. Do not move that job to a large or extra-large runner.

A missing reference records on the next run, and that run fails. To re-record references after an intended look change, run the CI workflow by hand on the branch with `record` set to `failed`. Download the `design-snapshots` artifact, look at every changed image, and commit the ones that are right. A failed comparison uploads the new image as `snapshot-failures`. No code change turns recording on.

Snapshots cover Home, the ad blocker pages, the machine pages, alerts, Settings, and the component gallery, in dark, default and largest Dynamic Type, on a small iPhone, a large iPhone, and an iPad.
