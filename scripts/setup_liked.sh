#!/bin/zsh
# Interactive, optional setup for the Liked-Songs auto-sync.
#
# Flowstate works fully WITHOUT this — it plays any Spotify playlist out of the box.
# This only turns your *Liked Songs* into a self-refreshing mirror playlist. Run it
# whenever (now or later): scripts/setup_liked.sh
set -e

REPO="${0:A:h:h}"                       # dir containing scripts/ (repo root or app Resources)
ENV_DIR="$HOME/.config/flowstate"
ENV_FILE="$ENV_DIR/sync.env"

print -r -- "
Flowstate — Liked Songs
───────────────────────
Spotify can't shuffle Liked Songs directly, so you point a slot at a mirror playlist.

★ EASIEST — no account setup, ~30 seconds (recommended):
    In Spotify: open Liked Songs → Cmd-A → right-click → Add to playlist →
    New playlist, then paste that playlist's link into a Flowstate slot
    (Settings ⚙ → Soundtrack). Done — you can stop here.

This tool is the OPTIONAL alternative: it builds that mirror for you and keeps it in
sync automatically every week. The trade-off is it needs your own free Spotify app —
just a Client ID (no password, no secret), ~2 min — because Spotify no longer lets one
shared app serve everyone.
"

printf "Set up the optional weekly auto-refresh now? [y/N] "
read -r ans || ans=""
if [[ "$ans" != [yY]* ]]; then
    print -r -- "Skipped. Re-run  scripts/setup_liked.sh  whenever you like."
    exit 0
fi

# Dependencies -------------------------------------------------------------
command -v python3 >/dev/null || { print -r -- "Need python3 (install Xcode command-line tools)."; exit 1; }
if ! python3 -c 'import spotipy' 2>/dev/null; then
    print -r -- "Installing the 'spotipy' library…"
    pip3 install --user spotipy
fi

# Client ID ----------------------------------------------------------------
print -r -- "
1) Create a free Spotify app, then paste its Client ID here:
     • Opening  https://developer.spotify.com/dashboard  → \"Create app\"
     • Redirect URI (exactly):   http://127.0.0.1:8888/callback
     • APIs used: check \"Web API\".  Copy the Client ID from the app's Settings.
       (Ignore the client secret — PKCE doesn't use one.)
"
open "https://developer.spotify.com/dashboard" 2>/dev/null || true
printf "Paste your Client ID: "
read -r CID || CID=""
[[ -n "$CID" ]] || { print -r -- "No Client ID — aborting."; exit 1; }

mkdir -p "$ENV_DIR"
cat > "$ENV_FILE" <<EOF
SPOTIPY_CLIENT_ID=$CID
SPOTIPY_REDIRECT_URI=http://127.0.0.1:8888/callback
EOF
chmod 600 "$ENV_FILE"
print -r -- "Saved your Client ID to $ENV_FILE"

# Install the runtime into ~/.config (out of TCC-protected folders) + schedule -
print -r -- "
2) Installing the weekly refresh and authorizing (a browser window will open —
   approve access; nothing is stored but an OAuth token)…"
"$REPO/scripts/install_sync_schedule.sh" >/dev/null
rm -f "$ENV_DIR/.cache-flowstate-liked-sync"      # force a fresh PKCE authorization

URI=$(zsh "$ENV_DIR/run_sync.sh" | tee /dev/tty | awk '/Liked-slot target/ {print $NF}')

print -r -- "
────────────────────────────────────────────
✓ Done. Your Liked Songs mirror auto-refreshes weekly (Sundays 04:00).
"
if [[ -n "$URI" ]]; then
    print -r -- "Point a Flowstate slot at this, in Settings ⚙ → Soundtrack → a slot's Target:
    $URI"
fi
