# Flowstate (macOS)

A macOS menu-bar Pomodoro timer with the current round visible **in the menu bar itself**
(e.g. `🍅 2/4 · 24:13`), plus a `spotify_player`-driven soundtrack that supports Liked-Songs
shuffle. A port of the [omarchy-flowstate](https://github.com/keegan-sucks/omarchy-flowstate)
Quickshell bar widget down to the essentials that matter on macOS.

## Requirements

- macOS 14+
- Full **Xcode** (to build the menu-bar GUI app)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`
- [spotify_player](https://github.com/aome510/spotify-player) + Spotify Premium — `brew install spotify_player` (music, Milestone 4)
- [AeroSpace](https://github.com/nikitabobko/AeroSpace) — optional, for placing the player on a workspace (Milestone 5)

## Build & run

The project is defined in `project.yml` (XcodeGen); the generated `.xcodeproj` is intentionally
git-ignored — regenerate it any time `project.yml` changes.

```bash
xcodegen generate
open Flowstate.xcodeproj      # then Cmd-R in Xcode
```

## Layout

```
Sources/
  FlowstateApp.swift        # @main App + MenuBarExtra (accessory activation policy)
  Views/
    PanelView.swift         # main panel: timer, round dots, transport, soundtrack
```

More files land as the milestones progress (TimerEngine, Settings, MusicController, …).
