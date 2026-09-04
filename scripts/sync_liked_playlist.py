#!/usr/bin/env python3
"""Mirror your Spotify **Liked Songs** into an ordinary playlist.

Liked Songs isn't a "context" the desktop app can shuffle on its own — which is
the only reason Flowstate ever needed spotify_player. This copies every saved
track into a normal playlist ("Liked (Flowstate)" by default) that the official
Spotify app shuffles like any other. Re-run it whenever you want to refresh the
snapshot (it *replaces* the playlist's contents, so it stays a faithful mirror).

Prints the playlist URI at the end — paste that into Flowstate's Liked slot.

────────────────────────────────────────────────────────────────────────────
ONE-TIME SETUP (≈2 min)
────────────────────────────────────────────────────────────────────────────
1. Create a personal Spotify app (this is the only step I can't do for you —
   it mints your own credentials):
     • Go to  https://developer.spotify.com/dashboard  → "Create app".
     • Name/description: anything (e.g. "Flowstate sync").
     • Redirect URI: add exactly   http://127.0.0.1:8888/callback
     • Save, then open the app's Settings to copy its Client ID and Client Secret.

2. Install the client library:
     pip3 install spotipy      # or: pipx install spotipy

3. Export your credentials (put these in ~/.zshrc to keep them, or paste per-run):
     export SPOTIPY_CLIENT_ID='...'
     export SPOTIPY_CLIENT_SECRET='...'
     export SPOTIPY_REDIRECT_URI='http://127.0.0.1:8888/callback'

4. Run it:
     python3 scripts/sync_liked_playlist.py

   The first run opens your browser once to authorize; the token is cached to
   .cache-flowstate-liked-sync next to wherever you run it, so later runs are
   silent. Nothing here ever stores your Spotify password — only an OAuth token.
"""

import os
import sys

try:
    import spotipy
    from spotipy.oauth2 import SpotifyOAuth
except ImportError:
    sys.exit("Missing dependency. Install it first:  pip3 install spotipy")

# The playlist we mirror into. Override with:  --name "Some Name"
PLAYLIST_NAME = "Liked (Flowstate)"
PLAYLIST_DESC = "Auto-synced mirror of Liked Songs (managed by Flowstate)."

# Scopes: read the library, read+write private playlists.
SCOPE = "user-library-read playlist-read-private playlist-modify-private playlist-modify-public"


def spotify_client() -> "spotipy.Spotify":
    missing = [v for v in ("SPOTIPY_CLIENT_ID", "SPOTIPY_CLIENT_SECRET", "SPOTIPY_REDIRECT_URI")
               if not os.environ.get(v)]
    if missing:
        sys.exit("Missing env var(s): " + ", ".join(missing) +
                 "\nSee the setup notes at the top of this file.")
    auth = SpotifyOAuth(scope=SCOPE, cache_path=".cache-flowstate-liked-sync",
                        open_browser=True)
    return spotipy.Spotify(auth_manager=auth)


def find_playlist(sp: "spotipy.Spotify", uid: str, name: str):
    """Return the id of a playlist owned by `uid` with this exact name, or None."""
    results = sp.current_user_playlists(limit=50)
    while results:
        for pl in results["items"]:
            if pl and pl["name"] == name and pl["owner"]["id"] == uid:
                return pl["id"]
        results = sp.next(results) if results.get("next") else None
    return None


def fetch_liked_uris(sp: "spotipy.Spotify") -> list[str]:
    """Every saved-track URI, newest first. Skips local files (not addable)."""
    uris: list[str] = []
    results = sp.current_user_saved_tracks(limit=50)
    while results:
        for item in results["items"]:
            t = item.get("track")
            if t and t.get("uri") and not t.get("is_local"):
                uris.append(t["uri"])
        results = sp.next(results) if results.get("next") else None
    return uris


def main() -> None:
    name = PLAYLIST_NAME
    if "--name" in sys.argv:
        name = sys.argv[sys.argv.index("--name") + 1]

    sp = spotify_client()
    me = sp.current_user()
    uid = me["id"]
    print(f"Signed in as {me.get('display_name') or uid}.")

    uris = fetch_liked_uris(sp)
    if not uris:
        sys.exit("No liked songs found — nothing to sync.")
    print(f"Found {len(uris)} liked track(s).")

    pid = find_playlist(sp, uid, name)
    if pid is None:
        # NB: Spotify's Feb 2026 Web API migration retired POST /users/{id}/playlists
        # (spotipy's user_playlist_create still targets it → 403). The replacement is
        # the self-scoped POST /me/playlists, which we call directly.
        created = sp._post("me/playlists", payload={
            "name": name, "public": False, "description": PLAYLIST_DESC})
        pid = created["id"]
        print(f'Created playlist "{name}".')
    else:
        print(f'Updating existing playlist "{name}".')

    # Replace contents (100 per call): first batch replaces, the rest append.
    sp.playlist_replace_items(pid, uris[:100])
    for i in range(100, len(uris), 100):
        sp.playlist_add_items(pid, uris[i:i + 100])

    uri = f"spotify:playlist:{pid}"
    print(f"\n✓ Synced {len(uris)} tracks into \"{name}\".")
    print(f"  Flowstate Liked-slot target:  {uri}")


if __name__ == "__main__":
    main()
