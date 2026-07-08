#!/usr/bin/env bash
# Despliega el bot Futbol en Apolo (u otro servidor Linux GlobalChat)
#
# Uso:
#   DEPLOY_HOST=globalchat@apolo.globalchat.org ./deploy-apolo.sh
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
REMOTE="${DEPLOY_HOST:?Define DEPLOY_HOST=globalchat@apolo.globalchat.org}"
REMOTE_DIR="${DEPLOY_DIR:-/home/globalchat/futbol_bot}"
SERVICE="futbol-bot.service"

echo "→ Desplegando en $REMOTE:$REMOTE_DIR"

ssh "$REMOTE" "mkdir -p '$REMOTE_DIR' ~/.config/systemd/user"

rsync -avz --delete \
  --exclude 'config.env' \
  --exclude 'futbol_state.json' \
  --exclude '*.log' \
  --exclude '*.pid' \
  --exclude '*.bak*' \
  --exclude 'futbol.plist.example' \
  --exclude 'www/' \
  "$DIR/" "$REMOTE:$REMOTE_DIR/"

rsync -avz "$DIR/futbol-bot.user.service" "$REMOTE:.config/systemd/user/$SERVICE"

ssh "$REMOTE" bash -s <<EOF
set -euo pipefail
cd '$REMOTE_DIR'

if [[ -f config.env ]]; then
  sed -i '/^ESPANA_WEB_URL=/d; /^ESPANA_JSON_PATH=/d' config.env
fi

if [[ ! -f config.env ]]; then
  cp config.env.example config.env
  sed -i 's|^IRC_HOST=.*|IRC_HOST=127.0.0.1|' config.env
  echo "Creado config.env (IRC_HOST=127.0.0.1)"
fi

rm -f /var/www/apolo.globalchat.org/mundial-espana.html /var/www/apolo.globalchat.org/espana.json 2>/dev/null || true

if [[ -f bot.pid ]] && kill -0 "\$(cat bot.pid)" 2>/dev/null; then
  kill "\$(cat bot.pid)" 2>/dev/null || true
  sleep 1
fi
rm -f bot.pid

systemctl --user daemon-reload
systemctl --user enable '$SERVICE'
systemctl --user restart '$SERVICE'
sleep 2
systemctl --user status '$SERVICE' --no-pager -l | tail -15
EOF

echo ""
echo "Remoto:"
echo "  ssh $REMOTE 'systemctl --user status $SERVICE'"
echo "  ssh $REMOTE 'journalctl --user -u $SERVICE -f'"
echo "  ssh $REMOTE 'systemctl --user restart $SERVICE'"
