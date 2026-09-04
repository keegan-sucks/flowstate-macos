#!/bin/zsh
# Install (or refresh) a weekly LaunchAgent that re-syncs your "Liked (Flowstate)"
# mirror playlist, so it keeps up as you like/unlike songs. Default cadence: weekly,
# Sundays at 04:00 (launchd runs it at the next wake if the Mac was asleep).
#
# It copies the sync's runtime into ~/.config/flowstate and runs it from there. That
# matters: macOS privacy (TCC) blocks background LaunchAgents from reading ~/Documents,
# ~/Desktop and ~/Downloads, so a job pointed at a repo in one of those folders fails
# with "can't open input file". ~/.config is not guarded.
#
# Prereqs: run scripts/sync_liked_playlist.py once (creates the playlist + token cache),
# and put your Spotify creds in ~/.config/flowstate/sync.env (see sync.env.example).
#
# Uninstall:  launchctl bootout gui/$UID/com.keegan.flowstate.liked-sync 2>/dev/null;
#             rm ~/Library/LaunchAgents/com.keegan.flowstate.liked-sync.plist
set -e

REPO="${0:A:h:h}"                                   # repo root (this script lives in scripts/)
DEST="$HOME/.config/flowstate"                      # TCC-safe runtime home
LABEL="com.keegan.flowstate.liked-sync"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/flowstate-liked-sync.log"
mkdir -p "$DEST" "$HOME/Library/LaunchAgents"

# Copy the runtime out of the repo into ~/.config/flowstate (plain cp also strips any
# quarantine xattr). sync.env is left untouched if you've already created it.
cp "$REPO/scripts/run_sync.sh"            "$DEST/run_sync.sh"
cp "$REPO/scripts/sync_liked_playlist.py" "$DEST/sync_liked_playlist.py"
chmod +x "$DEST/run_sync.sh"
# Reuse an existing OAuth token cache so the scheduled run never needs a browser.
if [[ -f "$REPO/.cache-flowstate-liked-sync" && ! -f "$DEST/.cache-flowstate-liked-sync" ]]; then
    cp "$REPO/.cache-flowstate-liked-sync" "$DEST/.cache-flowstate-liked-sync"
fi

cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/zsh</string>
        <string>$DEST/run_sync.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key><integer>0</integer>
        <key>Hour</key><integer>4</integer>
        <key>Minute</key><integer>0</integer>
    </dict>
    <key>RunAtLoad</key><false/>
    <key>StandardOutPath</key><string>$LOG</string>
    <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
PLISTEOF

# Reload cleanly (bootout the old instance if present, then bootstrap the new one).
launchctl bootout "gui/$UID/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$UID" "$PLIST"

echo "✓ Installed weekly Liked-mirror sync: $LABEL"
echo "  Schedule : Sundays 04:00 (weekly)"
echo "  Runtime  : $DEST/  (run_sync.sh, sync_liked_playlist.py, sync.env)"
echo "  Log      : $LOG"
echo "  Test now : launchctl kickstart -k gui/$UID/$LABEL"
