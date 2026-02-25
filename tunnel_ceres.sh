#!/bin/bash
# Túnel SSH a ceres.globalchat.org
# Uso:
#   ./tunnel_ceres.sh              → túnel SOCKS (proxy) en localhost:1080
#   ./tunnel_ceres.sh web          → acceso web de ceres en localhost:8080
#   ./tunnel_ceres.sh mysql        → MySQL de ceres en localhost:3306
#   ./tunnel_ceres.sh 8080:80      → custom: local 8080 → ceres:80
#   ./tunnel_ceres.sh 3306:localhost:3306  → custom

REMOTE="ceres.globalchat.org"
SOCKS_PORT="${SOCKS_PORT:-62500}"
WEB_LOCAL="${WEB_LOCAL:-8080}"
MYSQL_LOCAL="${MYSQL_LOCAL:-3306}"

case "${1:-socks}" in
  socks|proxy)
    echo "Túnel SOCKS: localhost:${SOCKS_PORT} → proxy vía $REMOTE"
    echo "Usar en navegador/app: SOCKS5 localhost:$SOCKS_PORT"
    echo "Ctrl+C para cerrar."
    exec ssh -N -D "${SOCKS_PORT}" "$REMOTE"
    ;;
  web)
    echo "Túnel web: http://localhost:${WEB_LOCAL} → $REMOTE:80"
    echo "Ctrl+C para cerrar."
    exec ssh -N -L "${WEB_LOCAL}:localhost:80" "$REMOTE"
    ;;
  mysql)
    echo "Túnel MySQL: localhost:${MYSQL_LOCAL} → $REMOTE:3306"
    echo "Conectar a 127.0.0.1:${MYSQL_LOCAL}"
    echo "Ctrl+C para cerrar."
    exec ssh -N -L "${MYSQL_LOCAL}:localhost:3306" "$REMOTE"
    ;;
  *)
    if [[ "$1" == *:* ]]; then
      # Formato: local_port:remote_host:remote_port o local_port:remote_port
      echo "Túnel: localhost:$1 → $REMOTE"
      echo "Ctrl+C para cerrar."
      exec ssh -N -L "$1" "$REMOTE"
    else
      echo "Uso: $0 [socks|web|mysql|LOCAL:REMOTE]"
      echo "  socks  - proxy SOCKS5 en localhost:${SOCKS_PORT}"
      echo "  web    - HTTP ceres en localhost:$WEB_LOCAL"
      echo "  mysql  - MySQL ceres en localhost:$MYSQL_LOCAL"
      echo "  N:M    - túnel local N → ceres:M"
      echo "  N:host:M - túnel local N → host:M vía ceres"
      exit 1
    fi
    ;;
esac
