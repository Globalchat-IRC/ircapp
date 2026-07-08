#!/usr/bin/env bash
# ponytail: reinicia spotify-icecast si cae; usar con nohup o launchd
set -uo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"
LOG="${DIR}/spotify_icecast.log"

while true; do
  echo "$(date '+%Y-%m-%d %H:%M:%S') INFO watchdog: arrancando spotify-icecast…" >>"$LOG"
  env PYTHONUNBUFFERED=1 ./run.sh -v >>"$LOG" 2>&1
  code=$?
  echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR watchdog: salió (code $code), reinicio en 10s" >>"$LOG"
  sleep 10
done
