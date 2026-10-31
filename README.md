# Raspberry Pi Stats

Raspberry Pi Stats is a native iPhone and iPad app for the Street house. Under the icon the name is Pi Stats, because the full name truncates. One app, one experience. It says what the house is doing in plain English. The GitHub repository stays `streetpi`. The code modules stay `StreetPi` and `StreetPiCore`.

The numbers are live. On the home Wi-Fi the app talks straight to the Pi. Away from home it reads the Pi's latest report from a small mailbox, see [Away mode](#away-mode). Tests, previews, and snapshots stay on fake fixtures and never open a socket. See `RELEASE-NOTES.md` for what each sideload changed.

Ad blocker & DNS opens the filter. Today shows blocking and a 24-hour chart of lookups. The only writes are a timed pause, blocking one domain, and allowing one domain. Each one asks in plain English first. Clients, groups, lists, local names, and upkeep are read-only. The text log file can be off; lookups are still kept. The app password stays in the Keychain, and the ad blocker's certificate is pinned.

Pi health is look-only. It shows the processor, temperature, memory, disk, and uptime, plus a day chart. Services and containers are readings. Alerts stay in the app and never name a person. The phone does not keep an SSH key.

## Away mode

The Pi pushes a read-only report to a free Cloudflare Worker, the mailbox: live numbers every 10 seconds and a day of history every 5 minutes. Nothing on the Pi listens to the internet, and no router port changes. See `mailbox/README.md`.

The app looks for the Pi first, for about 1.5 seconds. If the Pi doesn't answer it reads the mailbox instead. It looks again when the app comes to the front, when the network changes, and on pull-to-refresh. It never reads the Wi-Fi name and does nothing in the background.

Away is view-only. A badge shows how old the numbers are: "Away · updated 12s ago", a stale look after a minute, and "Pi hasn't reported in 3 min" after three. Pausing, the allow and deny lists, the logs, top domains and devices, and the device list show "Only at home".

Settings > Away holds the mailbox address and the read token. The token is masked, lives only in the Keychain, shows "Saved" with no way to reveal it, and can be removed.

### What leaves the house

Only these numbers and words go to the mailbox:

- Ad blocker: on, off, or unknown, today's lookups and blocked count, the blocked percent, how many domains are on the lists, a count of active devices, and lookup totals for the last day.
- The Pi: processor, memory, temperature, disk, uptime, and processor use for the last day.
- Checks: how many are up, plus the name and state of the service checks on the Pi's allowlist.
- Whether the streaming proxy is healthy, when the weekly backup last ran and whether it worked, and whether each reading was fresh.

These never leave: device or client names, IP and MAC addresses, the domains anyone looked up, top domains, hostnames, Wi-Fi names, people's names, ports, tokens, and passwords. The mailbox rejects a report with any field it doesn't know, so a bug on the Pi can't add one.

Cloudflare can see the report in transit, and stores the newest report and a day of history. The app has no analytics.

## Look

Aurora, dark only. There is no light palette and no appearance switch. Home is a Briefing and ring gauges for Processor, Temperature, Memory, and Disk. The Porch card and the Lampblack bar meters are retired. The only gradient is the Aurora glow family: the Home aura, the ring arcs, and the headline accent word. The launch film is `StreetPi/Resources/launch-film.mp4`, silent and full-screen on the Aurora ground. Tap to skip. It fades into the Home aura. Reduce Motion shows the poster, then fades, and does not play the video. Replace that one file to change the film. Do not add a second video. `LaunchOverlay` is the seam.

Keep Home compact and good-looking. A vertical stack is fine when the content fits. When a screen has a lot of data, many stat cards, graphs, or other dense information, do not make it a long one-card column. Choose the arrangement that looks best for that amount of content. There is no fixed column count. Large text must wrap or scroll, and nothing truncates or overlaps. The Home screen follows this.

Tabs are House, Ad blocker, Pi, and Settings. The iPad uses a sidebar.

Closed decisions are in `docs/project-context.md`. The rules are in `AGENTS.md`. Version 1.0.0 still draws the earlier porch screens, in Aurora colors. This section is the rule from 2026-10-24.

## Layout

- `StreetPiCore` — domain model, plain-English status, Pi and mailbox clients, fixtures. Pure Swift. `make test-core` runs on Linux.
- `StreetPi` — SwiftUI app. iOS 18 minimum, iPhone and iPad.
- `StreetPi.xcodeproj` — open this, or `StreetPi.xcworkspace`.
- `mailbox` — the Cloudflare Worker for Away mode. It has its own tests and deploy steps.

Bundle id defaults to `com.streetfam.streetpi`. Override `STREETPI_BUNDLE_IDENTIFIER` in `Config/Shared.xcconfig`. `STREETPI_APP_GROUP_IDENTIFIER` is reserved and is not an entitlement yet.

Secrets go in the iOS Keychain (`KeychainSecretStore`). Tests use `MemorySecretStore` and the strings `fixture-not-a-real-secret` and `fixture-not-a-real-password`. Those strings are never printed. The mailbox's tokens are Worker secrets, and nothing logs a token or a report.

## CI

GitHub Actions runs the core tests and the mailbox tests on Ubuntu and, on a standard `macos-26` runner, the snapshot matrix plus an unsigned `StreetPi-unsigned.ipa`. Do not move that job to a large or extra-large runner.

A missing reference records on the next run, and that run fails. To re-record references after an intended look change, run the CI workflow by hand on the branch with `record` set to `failed`. Download the `design-snapshots` artifact, look at every changed image, and commit the ones that are right. A failed comparison uploads the new image as `snapshot-failures`. No code change turns recording on.

Snapshots cover Home, the ad blocker pages, the machine pages, alerts, Settings, Away mode, and the component gallery, in dark, default and largest Dynamic Type, on a small iPhone, a large iPhone, and an iPad.
