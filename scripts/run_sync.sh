#!/bin/zsh
# Wrapper the weekly LaunchAgent runs (see install_sync_schedule.sh). It loads your
# Spotify API credentials, then runs the Liked-Songs mirror sync.
#
# Credentials, in priority order:
#   1. ~/.config/flowstate/sync.env   ← recommended for scheduled runs (KEY=VALUE per line):
#          SPOTIPY_CLIENT_ID=...
#          SPOTIPY_CLIENT_SECRET=...
#          SPOTIPY_REDIRECT_URI=http://127.0.0.1:8888/callback
#   2. otherwise it best-effort sources ~/.zshrc (where you may have exported them).
# Override the env-file path with FLOWSTATE_ENV.
set -e

ENV_FILE="${FLOWSTATE_ENV:-$HOME/.config/flowstate/sync.env}"
if [[ -f "$ENV_FILE" ]]; then
    set -a; source "$ENV_FILE"; set +a
elif [[ -f "$HOME/.zshrc" ]]; then
    source "$HOME/.zshrc" 2>/dev/null || true
fi

# Run from the repo root so the OAuth token cache (.cache-flowstate-liked-sync) is reused.
cd "${0:A:h}/.."
exec /usr/bin/python3 scripts/sync_liked_playlist.py "$@"
