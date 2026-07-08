#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
PY="$(command -v python3)"
PLIST="$HOME/Library/LaunchAgents/org.globalchat.spotify-icecast.plist"
sed -e "s|__DIR__|$DIR|g" -e "s|__PY__|$PY|g" "$DIR/spotify-icecast.plist.example" >"$PLIST"
launchctl bootout "gui/$(id -u)/org.globalchat.spotify-icecast" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
launchctl enable "gui/$(id -u)/org.globalchat.spotify-icecast"
launchctl kickstart -k "gui/$(id -u)/org.globalchat.spotify-icecast" 2>/dev/null || true
sleep 3
if pgrep -f "spotify_icecast.py" >/dev/null; then
  echo "OK launchd: $PLIST"
  exit 0
fi
echo "launchd no arrancó; usando watchdog…"
pkill -f "spotify-icecast/watchdog" 2>/dev/null || true
nohup "$DIR/watchdog.sh" >>"$DIR/spotify_icecast.log" 2>&1 &
echo "OK watchdog pid $!"
