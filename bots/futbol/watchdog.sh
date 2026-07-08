#!/bin/bash
# ponytail: bucle de reinicio; lanzar con nohup o launchd, no desde Cursor
set -uo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"
LOG="${DIR}/futbol.log"

if [[ -f config.env ]]; then
  set -a
  # shellcheck disable=SC1091
  source config.env
  set +a
fi

while true; do
  echo "$(date '+%Y-%m-%d %H:%M:%S') INFO watchdog: arrancando bot…" >>"$LOG"
  env PYTHONUNBUFFERED=1 python3 -u "$DIR/futbol_bot.py" -v >>"$LOG" 2>&1
  code=$?
  echo "$(date '+%Y-%m-%d %H:%M:%S') ERROR watchdog: bot salió (code $code), reinicio en 10s" >>"$LOG"
  sleep 10
done
