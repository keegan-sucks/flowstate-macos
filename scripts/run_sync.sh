#!/bin/zsh
# Wrapper the weekly LaunchAgent runs. install_sync_schedule.sh copies this (and
# sync_liked_playlist.py + the token cache) into ~/.config/flowstate and points the
# agent there — deliberately OUT of ~/Documents / ~/Desktop / ~/Downloads, which
# macOS privacy (TCC) blocks background LaunchAgents from reading.
#
# Credentials: loaded from sync.env next to this script (or ~/.config/flowstate/
# sync.env, or $FLOWSTATE_ENV) — just SPOTIPY_CLIENT_ID (PKCE; no secret). See
# sync.env.example. The token cache (.cache-flowstate-liked-sync) sits beside
# sync_liked_playlist.py, so it's found and reused regardless of cwd.
set -e

DIR="${0:A:h}"
for f in "$FLOWSTATE_ENV" "$DIR/sync.env" "$HOME/.config/flowstate/sync.env"; do
    if [[ -n "$f" && -f "$f" ]]; then
        set -a; source "$f"; set +a
        break
    fi
done

cd "$DIR"
exec /usr/bin/python3 "$DIR/sync_liked_playlist.py" "$@"
