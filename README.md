# Cubby

> A little creature that lives in your Mac's notch. Drop files on it, control your music, and glance at what matters — right from the black bar at the top of your screen.

Cubby turns the notch (or a small strip at the top of any Mac) into a **shelf**: hover to peek, click to open, drag a file onto it to stash it. It's a free, open-source, single-purpose take on the "notch hub" idea — no account, no daemon, no dependencies.

*Screenshots coming soon.*

## Features

- **Files** — drag any file onto the notch and it lands on a shelf; drag it back out wherever you need it.
- **Music** — control Apple Music from the notch: play/pause, skip, scrub, artwork.
- **Scores** — a glanceable live-scores tab (currently wired to the 2026 World Cup).
- **Side pins** — when closed, the notch shows Dynamic Island-style widgets: now playing, or a live score. Pin a tab manually, or let Cubby auto-pick.

## Requirements

- macOS 14 (Sonoma) or later. A notched Mac is ideal; on other Macs, Cubby falls back to a small strip at the top-center of the screen.
- The **Swift 6 toolchain** (Xcode 16 or later) to build.
- The **Apple Music** app, for the Music tab.

## Install

```sh
git clone https://github.com/ndaen/cubby-mac.git
cd cubby-mac
bash build-app.sh          # builds and installs /Applications/Cubby.app
open /Applications/Cubby.app
```

Cubby is an **agent app**: no Dock icon, it lives in the menu bar (a small face) and on the notch.

### Gatekeeper

The app is **ad-hoc signed, not notarized**. On first launch macOS may refuse to open it. Right-click `Cubby.app` → **Open** → **Open**, or run:

```sh
xattr -dr com.apple.quarantine /Applications/Cubby.app
```

### Launch at login

```sh
bash autostart.sh on       # start Cubby at every login
bash autostart.sh off      # stop
```

## Permissions

The first time you use the **Music** tab, macOS asks you to let Cubby control Apple Music (Apple Events). That is the only permission Cubby requests. No accessibility permission is needed — mouse tracking uses a global monitor that doesn't require it.

## Development

```sh
swift build                # debug build
swift run                  # build & run from the terminal
```

Cubby is **SwiftUI + AppKit**, built with **Swift Package Manager**, with **zero third-party runtime dependencies**. The notch window, shape, and shell state machine are adapted from [NotchDrop](https://github.com/Lakr233/NotchDrop) (MIT).

## Roadmap

- **Extensions & a marketplace** — turn each tab into an installable extension so anyone can add their own (including a better, richer agent monitor).
- **Pluggable scores** — other competitions and sports; make the tab optional.
- **Spotify** alongside Apple Music.
- **English UI** (the interface is currently in French) and notarized, auto-updating builds.

## Contributing

Issues and pull requests are welcome. Build with `swift build` before submitting.

## License

MIT — see [LICENSE](LICENSE). Cubby includes code adapted from NotchDrop (MIT); its notice is reproduced in [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).

---

*Why "Cubby"? The notch is a little cubby-hole at the top of your screen. Cubby is who lives in it.*
