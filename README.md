# Flowstate (macOS)

A macOS menu-bar Pomodoro timer with the current round visible **in the menu bar itself**
— e.g. `⌖ ●●○○ 12:34` — plus a `spotify_player`-driven focus soundtrack (Liked-Songs
shuffle included). A port of the [omarchy-flowstate](https://github.com/keegan-sucks/omarchy-flowstate)
Quickshell bar widget down to the essentials that matter on macOS.

## Features

- **Live in the menu bar:** a monochrome focus glyph, filled/empty round dots, and the
  running clock (`⌖ ●●○○ 12:34` focus, `☾ …` break). Glyphs are configurable.
- **Clean panel:** round dots, phase, big clock, Start/Pause · Skip · Reset, and three
  soundtrack slot buttons. Everything else lives in a resizable **Settings** window (⚙).
- **No timed long break:** after the last focus block the session ends with an audible cue
  (take your break whenever). Short breaks between blocks are timed.
- **Phase sounds:** distinct macOS system sounds for *short break*, *back to work*, and
  *long break* — each with its own sound picker + volume slider + preview.
- **Spotify soundtrack** via `spotify_player` (its own librespot Connect device, so
  **Liked-Songs shuffle** works — the native Spotify AppleScript can't do that):
  - **Liked** starts on a random track (`playback start liked --random`).
  - **Playlists/albums** start on a random track via a muted shuffle-and-skip (contexts
    always begin at track 1, so we start muted, shuffle, skip a few, then unmute).
  - Ducks to a configurable focus volume; **pauses during breaks**, resumes on focus;
    at the end of the cycle it pauses and restores your previous volume (the player is
    left open, not killed).
- **Workspace placement:** the player's terminal is moved to an AeroSpace workspace
  (default 9) by window-id, without stealing focus.
- **Now-playing notifications:** optional alert each time the song changes.

## Install

```bash
brew install --cask keegan-sucks/tap/flowstate
```

Flowstate is ad-hoc signed, so clear Gatekeeper on first launch (once) — or right-click
the app and choose Open:

```bash
xattr -dr com.apple.quarantine "/Applications/Flowstate.app"
```

Then authenticate the soundtrack once: `spotify_player authenticate` (needs Spotify
Premium). Optionally install [AeroSpace](https://github.com/nikitabobko/AeroSpace) for
workspace placement.

Update later with `brew update && brew upgrade --cask flowstate` (`brew update` refreshes
the tap first).

## Requirements (to build from source)

- macOS 14+
- Full **Xcode** (to build the menu-bar GUI app)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`
- [spotify_player](https://github.com/aome510/spotify-player) + Spotify **Premium** —
  `brew install spotify_player`, then `spotify_player authenticate`
- [AeroSpace](https://github.com/nikitabobko/AeroSpace) — optional, for workspace placement

## Build & run

The project is defined in `project.yml` (XcodeGen); the generated `.xcodeproj` is
git-ignored — regenerate it whenever `project.yml` changes.

```bash
xcodegen generate
xcodebuild -scheme Flowstate -configuration Debug -derivedDataPath build build
open build/Build/Products/Debug/Flowstate.app
# or: open Flowstate.xcodeproj  (then Cmd-R)
```

## Settings & shortcuts

Open the ⚙ (or press **E**). Sections: **General** (launch at login) · **Timer**
(durations, rounds) · **Menu-bar glyphs** · **Sounds** (per cue: choice + volume +
preview) · **Soundtrack** (play toggle, focus volume, always-shuffle, player workspace,
three editable slots). A slot **Target** is a Spotify URI/URL (`spotify:playlist:…`,
album, or artist) or the keyword `liked`. Settings persist across launches.

With the panel open: **Space** start/pause · **R** reset · **S** skip phase ·
**N** skip song · **E** edit · **Esc** close edit.

## Notes

- **Only hearing Liked songs?** Turn **off** Spotify → Settings → Playback → *Autoplay* —
  Liked Songs has no "context," so with Autoplay on, Spotify appends non-liked
  recommendations once the queued liked tracks run down.
- The player runs in **Terminal.app**; at cycle end the music is paused and the window is
  left open (Terminal keeps its window on this setup).

## Layout

```
Sources/
  FlowstateApp.swift      # @main App + MenuBarExtra
  TimerEngine.swift       # the Pomodoro state machine (round tracking lives here)
  Settings.swift          # persisted config (@Observable + UserDefaults)
  Sound.swift             # phase-cue sounds (NSSound)
  MusicController.swift    # spotify_player CLI + AeroSpace workspace placement
  Shell.swift             # small Process helper
  LoginItem.swift         # launch-at-login (SMAppService)
  Views/
    RootView.swift        # swaps panel / edit in the popover
    PanelView.swift       # the menu-bar panel
    EditView.swift        # the ⚙ edit view
scripts/
  release.sh              # cut a release + bump the Homebrew cask
```

## Releasing

Cut a new version and update the Homebrew cask in one step (uses your `gh` auth):

```bash
scripts/release.sh 1.1
```
