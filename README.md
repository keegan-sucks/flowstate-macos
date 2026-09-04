# Flowstate (macOS)

A macOS menu-bar Pomodoro timer with the current round visible **in the menu bar itself**
— e.g. `⌖ ●●○○ 12:34` — plus a focus soundtrack that drives the **official Spotify app**.
A port of the [omarchy-flowstate](https://github.com/keegan-sucks/omarchy-flowstate)
Quickshell bar widget down to the essentials that matter on macOS.

## Features

- **Live in the menu bar:** a monochrome focus glyph, filled/empty round dots, and the
  running clock (`⌖ ●●○○ 12:34` focus, `☾ …` break). Glyphs are configurable.
- **Clean panel:** round dots, phase, big clock, Start/Pause · Skip · Reset, three
  soundtrack slot buttons, and a skip-song button. Everything else lives in a
  resizable **Settings** view (⚙).
- **No timed long break:** after the last focus block the session ends with an audible cue
  (take your break whenever). Short breaks between blocks are timed.
- **Phase sounds:** distinct macOS system sounds for *short break*, *back to work*, and
  *long break* — each with its own sound picker + volume slider + preview.
- **Spotify soundtrack** through the official Spotify desktop app (via AppleScript — no
  extra player, no CLI, no login inside Flowstate):
  - Point each of the three slots at a Spotify **playlist, album, or artist** (its
    `spotify:…` URI or an `open.spotify.com` link). Switch slots live during focus.
  - Starts **shuffled** on a varied track (not always track 1), ducks to a configurable
    focus volume, **pauses during breaks** and resumes on focus, and at the end of the
    cycle pauses and restores your previous volume.
  - Rock-solid: it just remote-controls the app you already use, so there's no librespot
    Connect device to drop and no "no playback found."
- **Liked Songs** work too — via a mirror playlist (see below), since the desktop app
  can't shuffle Liked Songs directly.

## Install

```bash
brew install --cask keegan-sucks/tap/flowstate
```

This also installs the **Spotify** app if you don't have it. Flowstate is ad-hoc signed,
so clear Gatekeeper on first launch (once) — or right-click the app and choose Open:

```bash
xattr -dr com.apple.quarantine "/Applications/Flowstate.app"
```

On first play, macOS shows a one-time **"Flowstate wants to control Spotify"** prompt —
click OK. Log into Spotify (Premium recommended for gapless, ad-free focus), and you're set.

Update later with `brew update && brew upgrade --cask flowstate` (`brew update` refreshes
the tap first).

## Liked Songs (optional)

Everything above needs zero setup. Liked Songs is the one extra: the Spotify app can't
shuffle *Liked Songs* directly, so you mirror them into a normal playlist. Two ways —

- **By hand — no developer account:** in Spotify, open *Liked Songs* → `Cmd-A` →
  right-click → *Add to playlist* → *New playlist*, then paste that playlist's link into a
  slot (Settings ⚙ → Soundtrack). Done.

- **Auto-syncing — keeps up as you like/unlike:** run the guided setup and follow the
  prompts:

  ```bash
  scripts/setup_liked.sh
  ```

  It creates a "Liked (Flowstate)" playlist, prints the URI to paste into a slot, and
  installs a **weekly** refresh. Run it again anytime to set up or reconfigure — there's
  nothing to undo if you skipped it at first.

  This one path needs a **free Spotify app** of your own: Spotify no longer lets a single
  app serve many users, so each person registers their own at
  [developer.spotify.com/dashboard](https://developer.spotify.com/dashboard). You supply
  only a **Client ID — there is no secret** (it uses the PKCE flow, so nothing sensitive is
  ever stored). Under the hood: `scripts/sync_liked_playlist.py` does the sync,
  `scripts/install_sync_schedule.sh` installs the weekly LaunchAgent into `~/.config/flowstate`
  (out of `~/Documents`, which macOS blocks background jobs from reading), and your Client
  ID lives in `~/.config/flowstate/sync.env` (`scripts/sync.env.example`).

## Requirements (to build from source)

- macOS 14+
- Full **Xcode** (to build the menu-bar GUI app)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`
- The **Spotify** desktop app (`brew install --cask spotify`)
- Python 3 + [spotipy](https://github.com/spotipy-dev/spotipy) — only for the optional
  Liked-Songs mirror script

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
preview) · **Soundtrack** (play toggle, focus volume, always-shuffle, three editable
slots). A slot **Target** is a Spotify playlist/album/artist URI (`spotify:playlist:…`)
or an `open.spotify.com` link. Settings persist across launches.

With the panel open: **Space** start/pause · **R** reset · **S** skip phase ·
**N** skip song · **E** edit · **Esc** close edit.

## Layout

```
Sources/
  FlowstateApp.swift      # @main App + MenuBarExtra
  TimerEngine.swift       # the Pomodoro state machine (round tracking lives here)
  Settings.swift          # persisted config (@Observable + UserDefaults)
  Sound.swift             # phase-cue sounds (NSSound)
  MusicController.swift    # drives the Spotify app via AppleScript (osascript)
  Shell.swift             # small Process helper
  LoginItem.swift         # launch-at-login (SMAppService)
  Views/
    RootView.swift        # swaps panel / edit in the popover
    PanelView.swift       # the menu-bar panel
    EditView.swift        # the ⚙ edit view
scripts/
  release.sh                 # cut a release + bump the Homebrew cask
  sync_liked_playlist.py     # mirror Liked Songs → a playlist (optional)
  run_sync.sh                # wrapper the weekly sync LaunchAgent runs
  install_sync_schedule.sh   # install the weekly Liked-mirror sync
```

## Releasing

Cut a new version and update the Homebrew cask in one step (uses your `gh` auth):

```bash
scripts/release.sh 0.2.1
```
