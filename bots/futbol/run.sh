#!/usr/bin/env bash
# Arranca el bot Futbol en GlobalChat (#globalchat)
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"
LABEL="org.globalchat.futbol"
LOG="${DIR}/futbol.log"
LAUNCHD_LOG="${HOME}/Library/Logs/org.globalchat.futbol.log"
PIDF="${DIR}/futbol.pid"
WATCHDOG="${DIR}/watchdog.sh"
PLIST="${HOME}/Library/LaunchAgents/${LABEL}.plist"
UID_NUM="$(id -u)"
DOMAIN="gui/${UID_NUM}"

stop_daemon() {
  if [[ -f "$PIDF" ]]; then
    pid="$(cat "$PIDF" 2>/dev/null || true)"
    if [[ -n "${pid:-}" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
      sleep 1
      kill -9 "$pid" 2>/dev/null || true
    fi
    rm -f "$PIDF"
  fi
  pkill -f "$WATCHDOG" 2>/dev/null || true
}

if [[ -f config.env ]]; then
  set -a
  # shellcheck disable=SC1091
  source config.env
  set +a
fi

case "${1:-}" in
  --stop)
    launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
    stop_daemon
    echo "Futbol parado."
    exit 0
    ;;
  --status)
    if launchctl print "$DOMAIN/$LABEL" &>/dev/null; then
      echo "Servicio launchd: activo ($LABEL)"
    else
      echo "Servicio launchd: inactivo"
    fi
    if [[ -f "$PIDF" ]] && kill -0 "$(cat "$PIDF")" 2>/dev/null; then
      echo "Watchdog: PID $(cat "$PIDF")"
    else
      echo "Watchdog: inactivo"
    fi
    pgrep -fl futbol_bot.py || echo "Bot python: inactivo"
    exit 0
    ;;
  --install-macos)
    PY="$(command -v python3)"
    mkdir -p "${HOME}/Library/Logs"
    touch "$LAUNCHD_LOG"
    sed -e "s|__DIR__|$DIR|g" -e "s|__PY__|$PY|g" -e "s|__LOG__|$LAUNCHD_LOG|g" \
      "$DIR/futbol.plist.example" >"$PLIST"
    stop_daemon
    launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
    launchctl bootstrap "$DOMAIN" "$PLIST"
    launchctl enable "$DOMAIN/$LABEL"
    launchctl kickstart -k "$DOMAIN/$LABEL"
    echo "Futbol instalado como servicio macOS ($LABEL)"
    echo "Python: $PY"
    echo "Log launchd: $LAUNCHD_LOG"
    echo "Log manual (--daemon): $LOG"
    exit 0
    ;;
  -d|--daemon)
    chmod +x "$WATCHDOG"
    if [[ -f "$PIDF" ]]; then
      old_pid="$(cat "$PIDF" 2>/dev/null || true)"
      if [[ -n "${old_pid:-}" ]] && kill -0 "$old_pid" 2>/dev/null; then
        echo "Ya corre (PID $old_pid). ./run.sh --stop && ./run.sh --daemon"
        exit 0
      fi
      rm -f "$PIDF"
    fi
    # Desacoplado de la terminal (Cursor no lo mata al cerrar la sesión)
    nohup "$WATCHDOG" >>"$LOG" 2>&1 </dev/null &
    echo $! >"$PIDF"
    disown -h "$!" 2>/dev/null || true
    echo "Futbol en segundo plano — PID $(cat "$PIDF"), log: $LOG"
    echo "Tip: para que sobreviva reinicios usa ./run.sh --install-macos"
    exit 0
    ;;
esac

exec env PYTHONUNBUFFERED=1 python3 -u "$DIR/futbol_bot.py" "$@"
