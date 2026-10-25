# Raspberry Pi Stats 1.0.0 (2)

The first sideload. One app for the house, in plain English. Under the icon the name is Pi Stats. The repository stays `streetpi`.

- Opening plays a short silent film. Tap anywhere to skip. It fades into Home. Reduce Motion shows the final frame, then fades, and does not play the video.
- The app is dark only. There is no light look and no appearance switch.
- This build's Home is the porch card and the meters. Each part of the house opens from its own card. Aurora, chosen on 2026-10-24, retires that card and those bars. See `docs/project-context.md`.
- The iPad keeps a sidebar. Ad blocker and Pi health open as a list beside the page. Large text wraps.
- Motion stays calm, and it turns off when Reduce Motion is on.
- Ad blocker writes are still only three, and each one asks first: a timed pause that turns itself back on, block one name, allow one name.
- Pi health is a reading only. Nothing on that side can be changed.
- This build does not talk to the Pi. GitHub Actions builds the unsigned `StreetPi-unsigned.ipa` on the standard macOS runner.
