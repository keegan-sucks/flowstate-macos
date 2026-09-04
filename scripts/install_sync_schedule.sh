#!/bin/zsh
# Install (or refresh) a weekly LaunchAgent that re-syncs your "Liked (Flowstate)"
# mirror playlist, so it keeps up as you like/unlike songs. Default cadence: weekly,
# Sundays at 04:00 (launchd runs it at the next wake if the Mac was asleep).
#
# Prereqs: you've run scripts/sync_liked_playlist.py once (creates the playlist + token
# cache) and your Spotify creds are reachable by scripts/run_sync.sh (see that file).
#
# Uninstall:  launchctl bootout gui/$UID/com.keegan.flowstate.liked-sync 2>/dev/null;
#             rm ~/Library/LaunchAgents/com.keegan.flowstate.liked-sync.plist
set -e

REPO="${0:A:h:h}"                                   # repo root (this script lives in scripts/)
LABEL="com.keegan.flowstate.liked-sync"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG="$HOME/Library/Logs/flowstate-liked-sync.log"
mkdir -p "$HOME/Library/LaunchAgents"

cat > "$PLIST" <<PLISTEOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/zsh</string>
        <string>$REPO/scripts/run_sync.sh</string>
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
echo "  Runs     : $REPO/scripts/run_sync.sh"
echo "  Log      : $LOG"
echo "  Test now : launchctl kickstart -k gui/$UID/$LABEL"
