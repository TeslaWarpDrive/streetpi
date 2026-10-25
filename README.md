# StreetPi

StreetPi is a native iPhone and iPad app for the Street house. One app, one experience. It says what the house is doing in plain English.

The screen is drawn from fake fixtures. It does not talk to the Pi, the router, or any other host. Version 1.0.0 is the first sideload. See `RELEASE-NOTES.md`.

Ad blocker & DNS opens the filter. Today shows blocking and a 24-hour chart of lookups. The only writes are a timed pause, blocking one domain, and allowing one domain. Each one asks in plain English first. Clients, groups, lists, local names, and upkeep are read-only. The text log file can be off; lookups are still kept. The app password and the Pi certificate pin stay in the Keychain. Nothing in this build opens a socket.

Pi health is look-only. It shows the processor, temperature, memory, disk, and uptime, plus a day chart. Services and containers are readings. Alerts stay in the app and never name a person. Nothing here opens a connection, and the phone does not keep an SSH key or a host pin.

## Look

Aurora. Dark is designed first. Light mode is Daylight, and it is a real design. Home is a Briefing and ring gauges for Processor, Temperature, Memory, and Disk. The Porch card and the Lampblack bar meters are retired. The only gradient is the Aurora glow family: the Home aura, the ring arcs, and the headline accent word. The video splash stays. Its end tint is the Aurora ground.

Tabs are House, Ad blocker, Pi, and Settings. The iPad uses a sidebar. Settings has Appearance: System, Dark, Light.

Closed decisions are in `docs/project-context.md`. The rules are in `AGENTS.md`. Version 1.0.0 still draws the earlier porch screens, in Aurora colors. This section is the rule from 2026-10-24.

## Layout

- `StreetPiCore` — domain model, plain-English status, fixture clients. Pure Swift. `make test-core` runs on Linux.
- `StreetPi` — SwiftUI app. iOS 18 minimum, iPhone and iPad.
- `StreetPi.xcodeproj` — open this, or `StreetPi.xcworkspace`.

Bundle id defaults to `com.streetfam.streetpi`. Override `STREETPI_BUNDLE_IDENTIFIER` in `Config/Shared.xcconfig`. `STREETPI_APP_GROUP_IDENTIFIER` is reserved and is not an entitlement yet.

Secrets go in the iOS Keychain (`KeychainSecretStore`). Tests use `MemorySecretStore` and the strings `fixture-not-a-real-secret` and `fixture-not-a-real-password`. Those strings are never printed.

## CI

GitHub Actions runs the core tests on Ubuntu and, on a standard `macos-26` runner, the snapshot matrix plus an unsigned `StreetPi-unsigned.ipa`. Do not move that job to a large or extra-large runner.

Snapshots cover Home, the ad blocker pages, the machine pages, alerts, Settings, and the opening film, in dark and light, default and largest Dynamic Type, on a small iPhone, a large iPhone, and an iPad.
